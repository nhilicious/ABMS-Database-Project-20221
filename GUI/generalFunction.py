import json


def show_result(result, entry):
    entry.delete("1.0", "end")
    if result is None:
        entry.insert("1.0", "No data")
        return
    formatted_result = ''
    for i, index in enumerate(result):
        formatted_result += json.dumps(index, indent=4)
    entry.insert("1.0", formatted_result)
