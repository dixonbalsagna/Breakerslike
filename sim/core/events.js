// Output channel for the director feed: the prototype's feed(), writing S.out.feed instead of the DOM.
// The host drains S.out.feed; the QA adapter formats an entry as [t.toFixed(1) + 's', tag, sub].
export function feed(S, tag, sub){ S.out.feed.push({t: S.T, tag, sub}); }
