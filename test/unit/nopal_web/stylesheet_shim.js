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
      // _inserts / _deletes count CSSOM mutations, mirroring the dom_shim
      // _writes / _valueWrites pattern. Lets renderer tests assert that an
      // unchanged interactive re-render mutates no rule (FR-2/NFR-1) and that a
      // changed interaction releases exactly the rules it replaces (FR-2).
      var sheet = {
        _inserts: 0,
        _deletes: 0,
        get cssRules() {
          return rules;
        },
        insertRule: function (rule, index) {
          if (index === undefined) index = rules.length;
          rules.splice(index, 0, { cssText: rule });
          sheet._inserts++;
          return index;
        },
        deleteRule: function (index) {
          rules.splice(index, 1);
          sheet._deletes++;
        },
      };
      el.sheet = sheet;
    }
    return el;
  };
})();
