param value array
output value array = json('[${replace(replace(string(value), '[', ''), ']', '')}]')
