// CSSStyleSheet shim for style_sheet.ml tests.
//
// Patches the dom_shim's createElement so that <style> elements gain a
// fake CSSStyleSheet object with insertRule / deleteRule and a live
// cssRules array. Loaded AFTER dom_shim.js in the dune stanza.

(function () {
  var origCreate = globalThis.document.createElement.bind(globalThis.document);

  globalThis.document.createElement = function (tag) {
    var el = origCreate(tag);
    if (tag.toLowerCase() === "style") {
      var rules = [];
      el.sheet = {
        get cssRules() {
          return rules;
        },
        insertRule: function (rule, index) {
          if (index === undefined) index = rules.length;
          rules.splice(index, 0, { cssText: rule });
          return index;
        },
        deleteRule: function (index) {
          rules.splice(index, 1);
        },
      };
    }
    return el;
  };
})();
