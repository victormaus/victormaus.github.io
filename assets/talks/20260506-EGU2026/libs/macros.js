/* remark.js custom macros for the mtg-slides theme.
 *
 * Usage in a slide markdown:
 *   ![:scale 60%](path/to/image.png)
 */

remark.macros.scale = function (w) {
  var url = this;
  return '<img src="' + url + '" style="width: ' + w + '" />';
};
