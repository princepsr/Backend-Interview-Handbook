// Java Backend Interview Handbook — callout boxes

window.applyEnhancements = function() {
    var rules = [
        { re: /^interview trap/i,     cls: "callout-trap" },
        { re: /^common mistake/i,     cls: "callout-mistake" },
        { re: /^quick tip|^pro tip/i, cls: "callout-tip" },
        { re: /^quick revision/i,     cls: "callout-revision" },
        { re: /^real.world example/i, cls: "callout-example" },
        { re: /^follow.up question/i, cls: "callout-tip" },
    ];

    document.querySelectorAll(".content p").forEach(function(p) {
        var first = p.querySelector("strong");
        if (!first) return;
        // only match if strong is the first meaningful node
        if (p.firstChild !== first && !(p.firstChild.nodeType === 3 && p.firstChild.textContent.trim() === "")) return;
        var txt = first.textContent.trim();
        for (var i = 0; i < rules.length; i++) {
            if (rules[i].re.test(txt)) {
                p.classList.add(rules[i].cls);
                // also style the immediately following list
                var next = p.nextElementSibling;
                if (next && (next.tagName === "UL" || next.tagName === "OL")) {
                    next.classList.add(rules[i].cls);
                    next.style.marginTop = "0";
                    next.style.borderRadius = "0 0 8px 8px";
                    p.style.borderRadius = "0 8px 0 0";
                    p.style.marginBottom = "0";
                }
                break;
            }
        }
    });
};

// Run with a small delay to ensure mdBook has finished rendering
function runWhenReady() {
    setTimeout(window.applyEnhancements, 150);
}

document.addEventListener("DOMContentLoaded", runWhenReady);

// Re-run on mdBook chapter navigation
window.addEventListener("hashchange", runWhenReady);
window.addEventListener("popstate", runWhenReady);

// Fallback: also run immediately in case DOMContentLoaded already fired
if (document.readyState !== "loading") {
    runWhenReady();
}
