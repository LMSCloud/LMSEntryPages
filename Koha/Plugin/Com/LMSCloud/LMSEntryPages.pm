package Koha::Plugin::Com::LMSCloud::LMSEntryPages;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Auth;
use C4::Context;

use Koha::Account::Lines;
use Koha::Account;
use Koha::DateUtils;
use Koha::Libraries;
use Koha::Patron::Categories;
use Koha::Patron;

use Cwd qw(abs_path);
use Data::Dumper;
use LWP::UserAgent;
use MARC::Record;
use Mojo::JSON qw(decode_json);
use URI::Escape qw(uri_unescape);

## Here we set our plugin version
our $VERSION         = "1.0.0";
our $MINIMUM_VERSION = "21.05.04";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'LMSEntryPages',
    author          => 'LMSCloud GmbH',
    date_authored   => '2022-06-20',
    date_updated    => "2022-06-20",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     => 'Generate and edit LMSCloud\'s entry pages.',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## The existance of a 'tool' subroutine means the plugin is capable
## of running a tool. The difference between a tool and a report is
## primarily semantic, but in general any plugin that modifies the
## Koha database should be considered a tool
sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('submitted') ) {
        $self->tool_step1();
    }
    else {
        $self->tool_step2();
    }

}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    return 1;
}

## This is the 'upgrade' method. It will be triggered when a newer version of a
## plugin is installed over an existing older version of a plugin
sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    my $landing_page_item_table = $self->get_qualified_table_name('landing_page_items');

    C4::Context->dbh->do("DROP TABLE IF EXISTS $landing_page_item_table");

    return 1;
}

sub tool_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template( { file => 'tool-step1.tt' } );

    my $dbh                     = C4::Context->dbh;
    my $landing_page_item_table = $self->get_qualified_table_name('landing_page_items');

    my $landing_array_ref = $dbh->selectcol_arrayref( q{SELECT lang, content FROM opac_news;}, { Columns => [ 1, 2 ] } );
    my $entry_array_ref   = $dbh->selectcol_arrayref(
        q{SELECT variable, value FROM systempreferences WHERE variable IN ('OpacEntryPageChildto9_de-DE', 'OpacEntryPageChildto9_en', 'OpacEntryPageChildfrom9_de-DE', 'OpacEntryPageChildfrom9_en', 'OpacEntryPageAdult_de-DE', 'OpacEntryPageAdult_en');},
        { Columns => [ 1, 2 ] }
    );

    my %landing_page_items = @$landing_array_ref;
    my %entry_page_items   = @$entry_array_ref;

    # warn Dumper( '##### 1 #######################################################line: ' . __LINE__ );
    # warn Dumper( \%landing_page_items );
    # warn Dumper('##### end1 #######################################################');

    $template->param( landing_page_items => \%landing_page_items, entry_page_items => \%entry_page_items );

    $self->output_html( $template->output() );
}

sub tool_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $dbh = C4::Context->dbh;

    my $entry_page_identifier = $cgi->param('entryPageIdentifier');
    my $entry_page_content    = $cgi->param('entryPageContent');

    my @landing_page_identifiers = (
        'OpacNavRight_de-DE',          'OpacNavRight_en', 'OpacMainPageLeftPanel_de-DE', 'OpacMainPageLeftPanel_en',
        'opacheader_de-DE',            'opacheader_en',   'OpacMainUserBlock_de-DE',     'OpacMainUserBlock_en',
        'OpacLoginInstructions_de-DE', 'OpacLoginInstructions_en'
    );

    my @entry_page_identifiers = (
        'OpacEntryPageChildto9_de-DE', 'OpacEntryPageChildto9_en', 'OpacEntryPageChildfrom9_de-DE', 'OpacEntryPageChildfrom9_en',
        'OpacEntryPageAdult_de-DE',    'OpacEntryPageAdult_en'
    );

    if ( grep( $_ eq $entry_page_identifier, @landing_page_identifiers ) ) {
        my $sth = $dbh->prepare(q{UPDATE opac_news SET content = ? WHERE lang = ?});
        $sth->execute( $entry_page_content, $entry_page_identifier ) or die $dbh->errstr;
    }
    elsif ( grep( $_ eq $entry_page_identifier, @entry_page_identifiers ) ) {
        my $sth = $dbh->prepare(q{UPDATE systempreferences SET value = ? WHERE variable = ?});
        $sth->execute( $entry_page_content, $entry_page_identifier ) or die $dbh->errstr;
    }
    else {
        die qq{Something went wrong in the LMSEntryPages module. Maybe the entry_page_identifier: $entry_page_identifier isn't properly handled or misspelled.};
    }

    my $template = $self->get_template( { file => 'tool-step2.tt' } );

    $template->param(
        entry_page_identifier => $entry_page_identifier,
        entry_page_content    => $entry_page_content
    );

    $self->output_html( $template->output() );

}

## API methods
# If your plugin implements API routes, then the 'api_routes' method needs
# to be implemented, returning valid OpenAPI 2.0 paths serialized as a hashref.
# It is a good practice to actually write OpenAPI 2.0 path specs in JSON on the
# plugin and read it here. This allows to use the spec for mainline Koha later,
# thus making this a good prototyping tool.

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'kitchensink';
}

sub static_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('staticapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

1;
