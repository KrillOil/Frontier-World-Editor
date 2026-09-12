class_name EditorHistoryClock
extends RefCounted

static var _next_transaction_id := 1


static func claim() -> int:
	var transaction_id := _next_transaction_id
	_next_transaction_id += 1
	return transaction_id
