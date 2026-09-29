class_name SimEvents
## Output channel: the twin of events.js. feed() appends a line to S.out.feed; the host drains it.


static func feed(S: SimState, tag: String, sub: String) -> void:
	var l := SimState.FeedLine.new()
	l.t = S.T
	l.tag = tag
	l.sub = sub
	S.out.feed.append(l)
