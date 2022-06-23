# LMSEntryPages
Koha plugin that simplifies editing and updating LMSCloud's landing and entry pages. Uses bulma and the monaco-editor.

## Usage
* Select the page you'd like to edit via the corresponding page title in the **tabs**
* Select the localization of the current page via the **menu** on the **left**
* When you are done editing, save your work with the **Save** button
* When you are ready to write the changes to the database, click the **Submit** button
    * You will be redirected to the second page of the tool where you can view the new version of\
    the document you just edited
    * Click the **Back to editor** button to get back to the first page of the tool; you can also just\
    press enter because the button is focussed by default

## Important
If you change your tab, your changes are **GONE** even if you clicked the **Save** button.\
Saving the state of documents isn't implemented yet (Look at the [Roadmap](#Roadmap)).

## Roadmap
- [ ] Saving current edits in documents by clicking **Save** or when switching editor tabs.
- [ ] Automatically select the last editor tab you've worked when you enter the tool or after submitting.
- [ ] Integrate markup generation tools by LMSCloud.
- [ ] Make all strings automatically translatable (at least from german to english).
- [ ] Add a graphical component library where you can copy html to your clipboard.