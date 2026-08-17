class_name JsonhGd extends Object

class JsonhResultEnumerable extends RefCounted:
	var reader: JsonhReader
	var items: Array[JsonhResultEnumerableItem]
	var end_string_index: int

	func _init(_reader: JsonhReader, _items: Array[JsonhResultEnumerableItem], _end_string_index: int) -> void:
		reader = _reader
		items = _items
		end_string_index = _end_string_index

	func to_array() -> Array[JsonhResult]:
		var array: Array[JsonhResult] = []
		for enumerable_item: JsonhResultEnumerableItem in items:
			array.append(enumerable_item.result)
		return array

	func _iter_init(iter: Array) -> bool:
		iter[0] = 0
		if iter[0] >= len(items):
			reader.string_index = end_string_index
			return false
		var current_item: JsonhResultEnumerableItem = items[iter[0]]
		reader.string_index = current_item.string_index
		return true

	func _iter_next(iter: Array) -> bool:
		iter[0] += 1
		if iter[0] >= len(items):
			reader.string_index = end_string_index
			return false
		var current_item: JsonhResultEnumerableItem = items[iter[0]]
		reader.string_index = current_item.string_index
		return true

	func _iter_get(iter: Variant) -> JsonhResultEnumerableItem:
		return items[iter]

	func _to_string() -> String:
		return str("enumerable (", items, ")")

class JsonhResultEnumerableBuilder extends RefCounted:
	var reader: JsonhReader
	var items: Array[JsonhResultEnumerableItem]

	func _init(_reader: JsonhReader) -> void:
		reader = _reader
		items = []

	func append(index: int, result: JsonhResult) -> void:
		items.append(JsonhResultEnumerableItem.new(index, result))

	func finish(end_string_index: int) -> JsonhResultEnumerable:
		return JsonhResultEnumerable.new(reader, items, end_string_index)

	func _to_string() -> String:
		return str("enumerable builder (", items, ")")

class JsonhResultEnumerableItem extends RefCounted:
	var string_index: int
	var result: JsonhResult
	
	func _init(_string_index: int, _result: JsonhResult) -> void:
		string_index = _string_index
		result = _result

	func _to_string() -> String:
		return str("enumerable item (", result, ")")

class JsonhResult extends RefCounted:
	var is_error: bool
	var value_or_null: Variant
	var error_or_null: Variant

	func _init(_is_error: bool, _value_or_null: Variant = null, _error_or_null: Variant = null) -> void:
		is_error = _is_error
		value_or_null = _value_or_null
		error_or_null = _error_or_null

	static func from_value(_value: Variant = null) -> JsonhResult:
		return JsonhResult.new(false, _value, null)

	static func from_error(_error: Variant = null) -> JsonhResult:
		return JsonhResult.new(true, null, _error)

	func value() -> Variant:
		if is_error:
			push_error(str("Result was error: ", error_or_null))
			return null
		return value_or_null

	func error() -> Variant:
		if not is_error:
			push_error(str("Result was value: ", value_or_null))
			return null
		return error_or_null

	func _to_string() -> String:
		if is_error:
			return str("error (", error_or_null, ")")
		return str("value (", value_or_null, ")")

class JsonhRef extends RefCounted:
	var ref: Variant

	func _init(_ref: Variant) -> void:
		ref = _ref

	func _to_string() -> String:
		return str("ref (", ref, ")")

## The major versions of the JSONH specification.
enum JsonhVersion {
	## Indicates that the latest version should be used (currently V2).
	LATEST = 0,
	## Version 1 of the specification, released 2025/03/19.
	V1 = 1,
	## Version 2 of the specification, released 2025/11/19.
	V2 = 2,
}

## The types of tokens that make up a JSON document.
enum JsonTokenType {
	## Indicates that there is no value (not to be confused with NULL).
	NONE = 0,
	## The start of an object.
	## 
	## Example: `{`
	START_OBJECT = 1,
	## The end of an object.
	## 
	## Example: `}`
	END_OBJECT = 2,
	## The start of an array.
	## 
	## Example: `[`
	START_ARRAY = 3,
	## The end of an array.
	## 
	## Example: `]`
	END_ARRAY = 4,
	## A property name in an object.
	## 
	## Example: `"key":`
	PROPERTY_NAME = 5,
	## A comment.
	## 
	## Example: `// comment`
	COMMENT = 6,
	## A string.
	## 
	## Example: `"value"`
	STRING = 7,
	## A number.
	## 
	## Example: `10`
	NUMBER = 8,
	## A true boolean.
	## 
	## Example: `true`
	TRUE = 9,
	## A false boolean.
	## 
	## Example: `false`
	FALSE = 10,
	## A null value.
	## 
	## Example: `null`
	NULL = 11,
}

## A single JSONH token.
class JsonhToken extends RefCounted:
	var json_type: JsonTokenType
	var value: String

	func _init(_json_type: JsonTokenType, _value: String = "") -> void:
		json_type = _json_type
		value = _value

	func _to_string() -> String:
		return str("JsonhToken(", json_type, ", ", JSON.stringify(value), ")")

## Methods for parsing JSONH numbers.
## 
## Unlike `JsonhReader.read_element()`, minimal validation is done here. Ensure the input is valid.
class JsonhNumberParser extends Object:
	static func parse(jsonh_number: String) -> JsonhResult:
		# Remove underscores
		jsonh_number = jsonh_number.replace("_", "")
		var digits: String = jsonh_number

		# Get sign
		var number_sign: int = 1
		if digits.begins_with('-'):
			number_sign = -1
			digits = digits.substr(1)
		elif digits.begins_with('+'):
			number_sign = 1
			digits = digits.substr(1)

		# Decimal
		var base_digits: String = "0123456789"
		# Hexadecimal
		if digits.begins_with("0x") or digits.begins_with("0X"):
			base_digits = "0123456789abcdef"
			digits = digits.substr(2)
		# Binary
		elif digits.begins_with("0b") or digits.begins_with("0B"):
			base_digits = "01"
			digits = digits.substr(2)
		# Octal
		elif digits.begins_with("0o") or digits.begins_with("0O"):
			base_digits = "01234567"
			digits = digits.substr(2)

		# Parse number with base digits
		var number: JsonhResult = JsonhNumberParser._parse_fractional_number_with_exponent(digits, base_digits)
		if number.is_error:
			return number

		# Apply sign
		if number_sign != 1:
			number.value_or_null *= number_sign
		return number

	## Converts a fractional number with an exponent (e.g. `12.3e4.5`) from the given base (e.g. `01234567`) to a base-10 real.
	static func _parse_fractional_number_with_exponent(digits: String, base_digits: String) -> JsonhResult:
		# Find exponent
		var exponent_index: int = -1
		# Hexadecimal exponent
		if 'e' in base_digits:
			for index: int in range(0, len(digits)):
				if digits[index] not in ['e', 'E']:
					continue
				if index + 1 >= len(digits) or (digits[index + 1] not in ['-', '+']):
					continue
				exponent_index = index
				break
		# Exponent
		else:
			exponent_index = JsonhNumberParser._index_of_any(digits, ['e', 'E'])

		# If no exponent then parse real
		if exponent_index < 0:
			return JsonhNumberParser._parse_fractional_number(digits, base_digits)

		# Get mantissa and exponent
		var mantissa_part: String = digits.substr(0, exponent_index)
		var exponent_part: String = digits.substr(exponent_index + 1)

		# Parse mantissa and exponent
		var mantissa: JsonhResult = JsonhNumberParser._parse_fractional_number(mantissa_part, base_digits)
		if mantissa.is_error:
			return mantissa
		var exponent: JsonhResult = JsonhNumberParser._parse_fractional_number(exponent_part, base_digits)
		if exponent.is_error:
			return exponent

		# Multiply mantissa by 10 ^ exponent
		return JsonhResult.from_value(mantissa.value() * (10.0 ** exponent.value()))

	## Converts a fractional number (e.g. `123.45`) from the given base (e.g. `01234567`) to a base-10 real.
	static func _parse_fractional_number(digits: String, base_digits: String) -> JsonhResult:
		# Find dot index
		var dot_index: int = digits.find('.')
		# If no dot then normalize integer
		if dot_index < 0:
			return JsonhNumberParser._parse_whole_number(digits, base_digits)

		# Get parts of number
		var whole_part: String = digits.substr(0, dot_index)
		var fraction_part: String = digits.substr(dot_index + 1)

		# Parse parts of number
		var whole: JsonhResult = JsonhNumberParser._parse_whole_number(whole_part, base_digits)
		if whole.is_error:
			return whole

		# Add each column of fraction digits
		var fraction: float = 0.0
		for index: int in range(len(fraction_part) - 1, -1, -1):
			# Get current digit
			var digit_char: String = fraction_part[index]
			var digit_int: int = base_digits.find(digit_char.to_lower())

			# Ensure digit is valid
			if digit_int < 0:
				return JsonhResult.from_error(str("Invalid digit: '", digit_char, "'"))

			# Add value of column
			fraction = (fraction + digit_int) / len(base_digits)

		# Combine whole and fraction
		return JsonhResult.from_value(whole.value() + fraction)

	## Converts a whole number (e.g. `12345`) from the given base (e.g. `01234567`) to a base-10 integer.
	static func _parse_whole_number(digits: String, base_digits: String) -> JsonhResult:
		# Get sign
		var number_sign: int = 1
		if digits.begins_with('-'):
			number_sign = -1
			digits = digits.substr(1)
		elif digits.begins_with('+'):
			number_sign = 1
			digits = digits.substr(1)

		# Add each column of digits
		var integer: float = 0.0
		for index: int in range(0, len(digits)):
			# Get current digit
			var digit_char: String = digits[index]
			var digit_int: int = base_digits.find(digit_char.to_lower())

			# Ensure digit is valid
			if digit_int < 0:
				return JsonhResult.from_error(str("Invalid digit: '", digit_char, "'"))

			# Add value of column
			integer = (integer * len(base_digits)) + digit_int

		# Apply sign
		if number_sign != 1:
			integer *= number_sign
		return JsonhResult.from_value(integer)

	static func _index_of_any(input: String, chars: PackedStringArray) -> int:
		for i: int in range(0, len(input)):
			var input_char: String = input[i]
			if input_char in chars:
				return i
		return -1

## Options for a JsonhReader.
class JsonhReaderOptions extends RefCounted:
	## Specifies the major version of the JSONH specification to use.
	var version: JsonhVersion = JsonhVersion.LATEST
	## Enables/disables checks for exactly one element when parsing.
	## 
	## [codeblock]
	## "cat"
	## "dog" // Error: Expected single element
	## [/codeblock]
	## 
	## This option does not apply when reading elements, only when parsing elements.
	var parse_single_element: bool = false
	## Sets the maximum recursion depth allowed when reading JSONH.
	## 
	## [codeblock]
	## // Max depth: 2
	## {
	## a: {
	##    b: {
	##      // Error: Exceeded max depth
	##     }
	##   }
	## }
	## [/codeblock]
	## 
	## The default value is 64 to defend against DOS attacks.
	var max_depth: int = 64
	## Enables/disables parsing unclosed inputs.
	## 
	## [codeblock]
	## {
	##   "key": "val
	## [/codeblock]
	## 
	## This is potentially useful for large language models that stream responses.
	## 
	## Only some tokens can be incomplete in this mode, so it should not be relied upon.
	var incomplete_inputs: bool = false

	## Constructs options for a JsonhReader.
	func _init(_version: JsonhVersion = JsonhVersion.LATEST, _parse_single_element: bool = false, _max_depth: int = 64, _incomplete_inputs: bool = false) -> void:
		version = _version
		parse_single_element = _parse_single_element
		max_depth = _max_depth
		incomplete_inputs = _incomplete_inputs

	## Returns whether version is greater than or equal to minimum_version.
	func supports_version(minimum_version: JsonhVersion) -> bool:
		var latest_version: JsonhVersion = JsonhVersion.V2

		var options_version: JsonhVersion = latest_version if version == JsonhVersion.LATEST else version
		var given_version: JsonhVersion = latest_version if minimum_version == JsonhVersion.LATEST else minimum_version

		return options_version >= given_version

## A reader that reads JSONH tokens from a `String`.
class JsonhReader extends RefCounted:
	## The string to read characters from.
	var string: String
	## The index in the string.
	var string_index: int
	## The options to use when reading JSONH.
	var options: JsonhReaderOptions
	## The number of characters read from the string.
	var char_counter: int
	## The current recursion depth of the reader.
	var depth: int

	## Characters that cannot be used unescaped in quoteless strings.
	func _RESERVED_CHARS() -> PackedStringArray:
		return _RESERVED_CHARS_V2 if options.supports_version(JsonhVersion.V2) else _RESERVED_CHARS_V1

	## Characters that cannot be used unescaped in quoteless strings in JSONH V1.
	const _RESERVED_CHARS_V1: PackedStringArray = ['\\', ',', ':', '[', ']', '{', '}', '/', '#', '"', '\'']
	## Characters that cannot be used unescaped in quoteless strings in JSONH V2.
	const _RESERVED_CHARS_V2: PackedStringArray = ['\\', ',', ':', '[', ']', '{', '}', '/', '#', '"', '\'', '@']
	## Characters that are considered newlines.
	const _NEWLINE_CHARS: PackedStringArray = ['\n', '\r', '\u2028', '\u2029']
	## Characters that are considered whitespace.
	const _WHITESPACE_CHARS: PackedStringArray = [
		'\u0020', '\u00A0', '\u1680', '\u2000', '\u2001', '\u2002', '\u2003', '\u2004', '\u2005',
		'\u2006', '\u2007', '\u2008', '\u2009', '\u200A', '\u202F', '\u205F', '\u3000', '\u2028',
		'\u2029', '\u0009', '\u000A', '\u000B', '\u000C', '\u000D', '\u0085',
	]

	## Constructs a reader that reads JSONH from a string.
	func _init(_string: String, _options: JsonhReaderOptions = JsonhReaderOptions.new()) -> void:
		string = _string
		string_index = 0
		options = _options
		char_counter = 0
		depth = 0

	## Parses a single element from a string.
	static func parse_element_from_string(_string: String, _options: JsonhReaderOptions = JsonhReaderOptions.new()) -> JsonhResult:
		return JsonhReader.new(_string, _options).parse_element()

	## Parses a single element from the reader.
	func parse_element() -> JsonhResult:
		var current_elements: JsonhRef = JsonhRef.new([])
		var current_property_name: JsonhRef = JsonhRef.new(null)

		var submit_element := func(element: Variant) -> bool:
			# Root value
			if len(current_elements.ref) == 0:
				return true
			# Array item
			if current_property_name.ref == null:
				var current_array: Array = current_elements.ref[-1]
				current_array.append(element)
				return false
			# Object property
			else:
				var current_object: Dictionary = current_elements.ref[-1]
				current_object[current_property_name.ref] = element
				current_property_name.ref = null
				return false

		var start_element := func(element: Variant) -> void:
			submit_element.call(element)
			(current_elements.ref as Array).append(element)

		var parse_next_element := func() -> JsonhResult:
			for token_result_item: JsonhResultEnumerableItem in read_element():
				# Check error
				if token_result_item.result.is_error:
					return JsonhResult.from_error(token_result_item.result.error())

				match token_result_item.result.value().json_type:
					# Null
					JsonTokenType.NULL:
						var element: Variant = null
						if submit_element.call(element):
							return JsonhResult.from_value(element)
					# True
					JsonTokenType.TRUE:
						var element: bool = true
						if submit_element.call(element):
							return JsonhResult.from_value(element)
					# False
					JsonTokenType.FALSE:
						var element: bool = false
						if submit_element.call(element):
							return JsonhResult.from_value(element)
					# String
					JsonTokenType.STRING:
						var element: String = (token_result_item.result.value() as JsonhToken).value
						if submit_element.call(element):
							return JsonhResult.from_value(element)
					# Number
					JsonTokenType.NUMBER:
						var result: JsonhResult = JsonhNumberParser.parse((token_result_item.result.value() as JsonhToken).value)
						if result.is_error:
							return JsonhResult.from_error(result.error())
						var element: float = result.value()
						if submit_element.call(element):
							return JsonhResult.from_value(element)
					# Start Object
					JsonTokenType.START_OBJECT:
						var element: Dictionary[String, Variant] = {}
						start_element.call(element)
					# Start Array
					JsonTokenType.START_ARRAY:
						var element: Array = []
						start_element.call(element)
					# End Object/Array
					JsonTokenType.END_OBJECT, JsonTokenType.END_ARRAY:
						# Nested element
						if len(current_elements.ref) > 1:
							(current_elements.ref as Array).pop_back()
						# Root element
						else:
							return JsonhResult.from_value(current_elements.ref[-1])
					# Property Name
					JsonTokenType.PROPERTY_NAME:
						current_property_name.ref = (token_result_item.result.value() as JsonhToken).value
					# Comment
					JsonTokenType.COMMENT:
						pass
					# Not Implemented
					_:
						return JsonhResult.from_error("Token type not implemented")

			# End of input
			return JsonhResult.from_error("Expected token, got end of input")

		var next_element: JsonhResult = parse_next_element.call()

		# Ensure exactly one element
		if not next_element.is_error:
			if options.parse_single_element:
				for token_item: JsonhResultEnumerableItem in read_end_of_elements():
					if token_item.result.is_error:
						return JsonhResult.from_error(token_item.result.error())

		return next_element

	## Parses a single element as JSON from the reader.
	## 
	## If `include_comments` is true, comments are included (`/*` and `*/` are escaped as `/ *` and `* /`).
	## 
	## If `indent` is not null, the output is pretty-printed with the given indentation.
	## 
	## Note: The result is **NOT** safe to embed in HTML. To safely embed in HTML, you need to escape characters like `<`, `>` and `&`.
	func parse_json(include_comments: bool = false, indent: Variant = null) -> JsonhResult:
		var parse_next_element_as_json := func() -> JsonhResult:
			var current_depth: int = 0
			var is_start_of_structure: bool = true
			var is_property_value: bool = false

			var result_builder: String = ""

			for token_result_item: JsonhResultEnumerableItem in read_element():
				# Check error
				if token_result_item.result.is_error:
					return JsonhResult.from_error(token_result_item.result.error())
				var token: JsonhToken = token_result_item.result.value()

				# Add comments and indents
				if not is_property_value:
					# Add comma before property/item
					if (token.json_type not in [JsonTokenType.NONE, JsonTokenType.COMMENT]) and (current_depth > 0) and (not is_start_of_structure):
						# Don't add trailing comma
						if token.json_type not in [JsonTokenType.END_OBJECT, JsonTokenType.END_ARRAY]:
							result_builder += ','

					# Apply indentation
					if indent != null:
						# Don't indent inside empty structures
						if not (token.json_type in [JsonTokenType.END_OBJECT, JsonTokenType.END_ARRAY] and is_start_of_structure):
							# Don't indent comment if not included
							if not (token.json_type == JsonTokenType.COMMENT and (not include_comments)):
								# Don't indent root elements
								if current_depth > 0:
									# Add newline before element
									result_builder += '\n'

									# Get current indent count
									var indent_count: int = current_depth
									if token.json_type in [JsonTokenType.END_OBJECT, JsonTokenType.END_ARRAY]:
										indent_count -= 1

									# Add indent
									for _i: int in range(0, indent_count):
										result_builder += indent
				# Track start of structure to avoid adding leading comma
				if token.json_type not in [JsonTokenType.NONE, JsonTokenType.COMMENT]:
					is_start_of_structure = false
				if token.json_type in [JsonTokenType.START_OBJECT, JsonTokenType.START_ARRAY]:
					is_start_of_structure = true

				match token.json_type:
					# Null
					JsonTokenType.NONE:
						result_builder += "null"
						if current_depth == 0:
							return JsonhResult.from_value(result_builder)
					# True
					JsonTokenType.TRUE:
						result_builder += "true"
						if current_depth == 0:
							return JsonhResult.from_value(result_builder)
					# False
					JsonTokenType.FALSE:
						result_builder += "false"
						if current_depth == 0:
							return JsonhResult.from_value(result_builder)
					# String
					JsonTokenType.STRING:
						result_builder += JSON.stringify(token.value)
						if current_depth == 0:
							return JsonhResult.from_value(result_builder)
					# Number
					JsonTokenType.NUMBER:
						var result: JsonhResult = JsonhNumberParser.parse((token_result_item.result.value() as JsonhToken).value)
						if result.is_error:
							return JsonhResult.from_error(result.error())
						result_builder += str(result.value()).trim_suffix(".0")
						if current_depth == 0:
							return JsonhResult.from_value(result_builder)
					# Start Object
					JsonTokenType.START_OBJECT:
						result_builder += '{'
						current_depth += 1
					# Start Array
					JsonTokenType.START_ARRAY:
						result_builder += '['
						current_depth += 1
					# End Object
					JsonTokenType.END_OBJECT:
						result_builder += '}'
						current_depth -= 1
						if current_depth == 0:
							return JsonhResult.from_value(result_builder)
					# End Array
					JsonTokenType.END_ARRAY:
						result_builder += ']'
						current_depth -= 1
						if current_depth == 0:
							return JsonhResult.from_value(result_builder)
					# Property Name
					JsonTokenType.PROPERTY_NAME:
						result_builder += JSON.stringify(token.value)
						result_builder += ':'
						if indent != null:
							result_builder += ' '
					# Comment
					JsonTokenType.COMMENT:
						if include_comments:
							result_builder += "/*"
							result_builder += token.value.replace("/*", "/ *").replace("*/", "* /")
							result_builder += "*/"
					# Not implemented
					_:
						return JsonhResult.from_error("Token type not implemented")

				if token.json_type != JsonTokenType.COMMENT:
					is_property_value = token.json_type == JsonTokenType.PROPERTY_NAME

			# End of input
			return JsonhResult.from_error("Expected token, got end of input")

		var next_element_as_json: JsonhResult = parse_next_element_as_json.call()

		# Ensure exactly one element
		if not next_element_as_json.is_error:
			if options.parse_single_element:
				for token_item: JsonhResultEnumerableItem in read_end_of_elements():
					if token_item.result.is_error:
						return JsonhResult.from_error(token_item.result.error())

		return next_element_as_json

	## Tries to find the given property name in the reader.
	## For example, to find `c`:
	## [codeblock]
	## // Original position
	## {
	##   "a": "1",
	##   "b": {
	##     "c": "2"
	##   },
	##   "c":/* Final position */ "3"
	## }
	## [/codeblock]
	func find_property_value(property_name: String) -> bool:
		var current_depth: int = 0

		for token_result_item: JsonhResultEnumerableItem in read_element():
			# Check error
			if token_result_item.result.is_error:
				return false

			match token_result_item.result.value().json_type:
				# Start structure
				JsonTokenType.START_OBJECT, JsonTokenType.START_ARRAY:
					current_depth += 1
				# End structure
				JsonTokenType.END_OBJECT, JsonTokenType.END_ARRAY:
					current_depth -= 1
				# Property name
				JsonTokenType.PROPERTY_NAME:
					if current_depth == 1 and (token_result_item.result.value() as JsonhToken).value == property_name:
						# Path found
						return true

		# Path not found
		return false

	## Reads whitespace and returns whether the reader contains another token.
	func has_token() -> bool:
		# Whitespace
		_read_whitespace()

		# Peek char
		return _peek() != null

	## Reads comments and whitespace and errors if the reader contains another element.
	func read_end_of_elements() -> JsonhResultEnumerable:
		var enumerable := JsonhResultEnumerableBuilder.new(self)

		# Comments & whitespace
		for token_item: JsonhResultEnumerableItem in _read_comments_and_whitespace():
			if token_item.result.is_error:
				enumerable.append(string_index, JsonhResult.from_error(token_item.result.error()))
				return enumerable.finish(string_index)
			enumerable.append(string_index, token_item.result)

		# Peek char
		if _peek() != null:
			enumerable.append(string_index, JsonhResult.from_error("Expected end of elements"))

		return enumerable.finish(string_index)

	## Reads a single element from the reader.
	func read_element() -> JsonhResultEnumerable:
		var enumerable := JsonhResultEnumerableBuilder.new(self)

		# Comments & whitespace
		for token_item: JsonhResultEnumerableItem in _read_comments_and_whitespace():
			if token_item.result.is_error:
				enumerable.append(string_index, JsonhResult.from_error(token_item.result.error()))
				return enumerable.finish(string_index)
			enumerable.append(string_index, token_item.result)

		# Peek char
		var next: Variant = _peek()
		if next == null:
			enumerable.append(string_index, JsonhResult.from_error("Expected token, got end of input"))
			return enumerable.finish(string_index)

		# Object
		if next == '{':
			for token_item: JsonhResultEnumerableItem in _read_object():
				if token_item.result.is_error:
					enumerable.append(string_index, JsonhResult.from_error(token_item.result.error()))
					return enumerable.finish(string_index)
				enumerable.append(string_index, token_item.result)
		# Array
		elif next == '[':
			for token_item: JsonhResultEnumerableItem in _read_array():
				if token_item.result.is_error:
					enumerable.append(string_index, JsonhResult.from_error(token_item.result.error()))
					return enumerable.finish(string_index)
				enumerable.append(string_index, token_item.result)
		# Primitive value (null, true, false, string, number)
		else:
			var token: JsonhResult = _read_primitive_element()
			if token.is_error:
				enumerable.append(string_index, JsonhResult.from_error(token.error()))
				return enumerable.finish(string_index)

			# Detect braceless object from property name
			for token2_item: JsonhResultEnumerableItem in _read_braceless_object_or_end_of_primitive(token.value() as JsonhToken):
				if token2_item.result.is_error:
					enumerable.append(string_index, token2_item.result)
					return enumerable.finish(string_index)
				enumerable.append(string_index, token2_item.result)
		
		return enumerable.finish(string_index)

	func _read_object() -> JsonhResultEnumerable:
		var enumerable := JsonhResultEnumerableBuilder.new(self)
		
		# Opening brace
		if not _read_one('{'):
			# Braceless object
			for token_item: JsonhResultEnumerableItem in _read_braceless_object():
				if token_item.result.is_error:
					enumerable.append(string_index, token_item.result)
					return enumerable.finish(string_index)
				enumerable.append(string_index, token_item.result)
		# Start of object
		enumerable.append(string_index, JsonhResult.from_value(JsonhToken.new(JsonTokenType.START_OBJECT)))
		depth += 1

		# Check exceeded max depth
		if depth > options.max_depth:
			enumerable.append(string_index, JsonhResult.from_error("Exceeded max depth"))
			return enumerable.finish(string_index)

		while true:
			# Comments & whitespace
			for token_item: JsonhResultEnumerableItem in _read_comments_and_whitespace():
				if token_item.result.is_error:
					enumerable.append(string_index, token_item.result)
					return enumerable.finish(string_index)
				enumerable.append(string_index, token_item.result)

			var next: Variant = _peek()
			if next == null:
				# End of incomplete object
				if options.incomplete_inputs:
					depth -= 1
					enumerable.append(string_index, JsonhResult.from_value(JsonhToken.new(JsonTokenType.END_OBJECT)))
					return enumerable.finish(string_index)
				# Missing closing brace
				enumerable.append(string_index, JsonhResult.from_error("Expected `}` to end object, got end of input"))
				return enumerable.finish(string_index)

			# Closing brace
			if next == '}':
				# End of object
				_read()
				depth -= 1
				enumerable.append(string_index, JsonhResult.from_value(JsonhToken.new(JsonTokenType.END_OBJECT)))
				return enumerable.finish(string_index)
			# Property
			else:
				for token_item: JsonhResultEnumerableItem in _read_property():
					if token_item.result.is_error:
						enumerable.append(string_index, token_item.result)
						return enumerable.finish(string_index)
					enumerable.append(string_index, token_item.result)
		
		return enumerable.finish(string_index)

	func _read_braceless_object(property_name_tokens: Variant = null) -> JsonhResultEnumerable:
		var enumerable := JsonhResultEnumerableBuilder.new(self)
		
		# Start of object
		enumerable.append(string_index, JsonhResult.from_value(JsonhToken.new(JsonTokenType.START_OBJECT)))
		depth += 1

		# Check exceeded max depth
		if depth > options.max_depth:
			enumerable.append(string_index, JsonhResult.from_error("Exceeded max depth"))
			return enumerable.finish(string_index)

		# Initial tokens
		if property_name_tokens != null:
			for initial_token_item: JsonhResultEnumerableItem in _read_property(property_name_tokens):
				if initial_token_item.result.is_error:
					enumerable.append(string_index, initial_token_item.result)
					return enumerable.finish(string_index)
				enumerable.append(string_index, initial_token_item.result)

		while true:
			# Comments & whitespace
			for token_item: JsonhResultEnumerableItem in _read_comments_and_whitespace():
				if token_item.result.is_error:
					enumerable.append(string_index, token_item.result)
					return enumerable.finish(string_index)
				enumerable.append(string_index, token_item.result)

			if _peek() == null:
				# End of braceless object
				depth -= 1
				enumerable.append(string_index, JsonhResult.from_value(JsonhToken.new(JsonTokenType.END_OBJECT)))
				return enumerable.finish(string_index)

			# Property
			for token_item: JsonhResultEnumerableItem in _read_property():
				if token_item.result.is_error:
					enumerable.append(string_index, token_item.result)
					return enumerable.finish(string_index)
				enumerable.append(string_index, token_item.result)
		
		return enumerable.finish(string_index)

	func _read_braceless_object_or_end_of_primitive(primitive_token: JsonhToken) -> JsonhResultEnumerable:
		var enumerable := JsonhResultEnumerableBuilder.new(self)

		# Comments & whitespace
		var property_name_tokens: Variant = null
		for comment_or_whitespace_token_item: JsonhResultEnumerableItem in _read_comments_and_whitespace():
			if comment_or_whitespace_token_item.result.is_error:
				enumerable.append(string_index, comment_or_whitespace_token_item.result)
				return enumerable.finish(string_index)
			if property_name_tokens == null:
				property_name_tokens = [] as Array[JsonhToken]
			(property_name_tokens as Array[JsonhToken]).append(comment_or_whitespace_token_item.result.value())

		# Primitive
		if not _read_one(':'):
			# Primitive
			enumerable.append(string_index, JsonhResult.from_value(primitive_token))
			# Comments & whitespace
			if property_name_tokens != null:
				for comment_or_whitespace_token: JsonhToken in property_name_tokens:
					enumerable.append(string_index, JsonhResult.from_value(comment_or_whitespace_token))
			# End of primitive
			return enumerable.finish(string_index)

		# Property name
		if property_name_tokens == null:
			property_name_tokens = []
		(property_name_tokens as Array[JsonhToken]).append(JsonhToken.new(JsonTokenType.PROPERTY_NAME, primitive_token.value))

		# Braceless object
		for object_token_item: JsonhResultEnumerableItem in _read_braceless_object(property_name_tokens):
			if object_token_item.result.is_error:
				enumerable.append(string_index, object_token_item.result)
				return enumerable.finish(string_index)
			enumerable.append(string_index, object_token_item.result)
		
		return enumerable.finish(string_index)

	func _read_property(property_name_tokens: Variant = null) -> JsonhResultEnumerable:
		var enumerable := JsonhResultEnumerableBuilder.new(self)
		
		if property_name_tokens != null:
			for token: JsonhToken in property_name_tokens:
				enumerable.append(string_index, JsonhResult.from_value(token))
		else:
			for token_item: JsonhResultEnumerableItem in _read_property_name():
				if token_item.result.is_error:
					enumerable.append(string_index, token_item.result)
					return enumerable.finish(string_index)
				enumerable.append(string_index, token_item.result)

		# Comments & whitespace
		for token_item: JsonhResultEnumerableItem in _read_comments_and_whitespace():
			if token_item.result.is_error:
				enumerable.append(string_index, token_item.result)
				return enumerable.finish(string_index)
			enumerable.append(string_index, token_item.result)
		
		# Property value
		for token_item: JsonhResultEnumerableItem in read_element():
			if token_item.result.is_error:
				enumerable.append(string_index, token_item.result)
				return enumerable.finish(string_index)
			enumerable.append(string_index, token_item.result)

		# Comments & whitespace
		for token_item: JsonhResultEnumerableItem in _read_comments_and_whitespace():
			if token_item.result.is_error:
				enumerable.append(string_index, token_item.result)
				return enumerable.finish(string_index)
			enumerable.append(string_index, token_item.result)

		# Optional comma
		_read_one(',')
		
		return enumerable.finish(string_index)

	func _read_property_name() -> JsonhResultEnumerable:
		var enumerable := JsonhResultEnumerableBuilder.new(self)
		
		# String
		var string_token: JsonhResult = _read_string()
		if string_token.is_error:
			enumerable.append(string_index, string_token)
			return enumerable.finish(string_index)
		
		# Comments & whitespace
		for token_item: JsonhResultEnumerableItem in _read_comments_and_whitespace():
			if token_item.result.is_error:
				enumerable.append(string_index, token_item.result)
				return enumerable.finish(string_index)
			enumerable.append(string_index, token_item.result)

		# Colon
		if not _read_one(':'):
			enumerable.append(string_index, JsonhResult.from_error("Expected `:` after property name in object"))
			return enumerable.finish(string_index)

		# End of property name
		enumerable.append(string_index, JsonhResult.from_value(JsonhToken.new(JsonTokenType.PROPERTY_NAME, (string_token.value() as JsonhToken).value)))
		
		return enumerable.finish(string_index)

	func _read_array() -> JsonhResultEnumerable:
		var enumerable := JsonhResultEnumerableBuilder.new(self)
		
		# Opening bracket
		if not _read_one('['):
			enumerable.append(string_index, JsonhResult.from_error("Expected `[` to start array"))
			return enumerable.finish(string_index)
		# Start of array
		enumerable.append(string_index, JsonhResult.from_value(JsonhToken.new(JsonTokenType.START_ARRAY)))
		depth += 1

		# Check exceeded max depth
		if depth > options.max_depth:
			enumerable.append(string_index, JsonhResult.from_error("Exceeded max depth"))
			return enumerable.finish(string_index)

		while true:
			# Comments & whitespace
			for token_item: JsonhResultEnumerableItem in _read_comments_and_whitespace():
				if token_item.result.is_error:
					enumerable.append(string_index, token_item.result)
					return enumerable.finish(string_index)
				enumerable.append(string_index, token_item.result)

			var next: Variant = _peek()
			if next == null:
				# End of incomplete array
				if options.incomplete_inputs:
					depth -= 1
					enumerable.append(string_index, JsonhResult.from_value(JsonhToken.new(JsonTokenType.END_ARRAY)))
					return enumerable.finish(string_index)
				# Missing closing bracket
				enumerable.append(string_index, JsonhResult.from_error("Expected `]` to end array, got end of input"))
				return enumerable.finish(string_index)

			# Closing bracket
			if next == ']':
				# End of array
				_read()
				depth -= 1
				enumerable.append(string_index, JsonhResult.from_value(JsonhToken.new(JsonTokenType.END_ARRAY)))
				return enumerable.finish(string_index)
			# Item
			else:
				for token_item: JsonhResultEnumerableItem in _read_item():
					if token_item.result.is_error:
						enumerable.append(string_index, token_item.result)
						return enumerable.finish(string_index)
					enumerable.append(string_index, token_item.result)
		
		return enumerable.finish(string_index)

	func _read_item() -> JsonhResultEnumerable:
		var enumerable := JsonhResultEnumerableBuilder.new(self)
		
		# Element
		for token_item: JsonhResultEnumerableItem in read_element():
			if token_item.result.is_error:
				enumerable.append(string_index, token_item.result)
				return enumerable.finish(string_index)
			enumerable.append(string_index, token_item.result)

		# Comments & whitespace
		for token_item: JsonhResultEnumerableItem in _read_comments_and_whitespace():
			if token_item.result.is_error:
				enumerable.append(string_index, token_item.result)
				return enumerable.finish(string_index)
			enumerable.append(string_index, token_item.result)

		# Optional comma
		_read_one(',')
		
		return enumerable.finish(string_index)

	func _read_string() -> JsonhResult:
		# Verbatim
		var is_verbatim: bool = false
		if options.supports_version(JsonhVersion.V2) and _read_one('@'):
			is_verbatim = true

			# Ensure string immediately follows verbatim symbol
			var next: Variant = _peek()
			if next == null or next == '#' or next == '/' or next in _WHITESPACE_CHARS:
				return JsonhResult.from_error("Expected string to immediately follow verbatim symbol")

		# Start quote
		var start_quote: Variant = _read_any('"', '\'')
		if start_quote == null:
			return _read_quoteless_string("", is_verbatim)

		# Count multiple quotes
		var start_quote_counter: int = 1
		while _read_one(start_quote as String):
			start_quote_counter += 1

		# Empty string
		if start_quote_counter == 2:
			return JsonhResult.from_value(JsonhToken.new(JsonTokenType.STRING, ""))

		# Count multiple end quotes
		var end_quote_counter: int = 0

		# Read string
		var string_builder: String = ""

		while true:
			var next: String = _read()
			if next == null:
				return JsonhResult.from_error("Expected end of string, got end of input")

			# Partial end quote was actually part of string
			if next != start_quote:
				string_builder += (start_quote as String).repeat(end_quote_counter)
				end_quote_counter = 0

			# End quote
			if next == start_quote:
				end_quote_counter += 1
				if end_quote_counter == start_quote_counter:
					break
			# Escape sequence
			elif next == '\\':
				if is_verbatim:
					string_builder += next
				else:
					var escape_sequence_result: JsonhResult = _read_escape_sequence()
					if escape_sequence_result.is_error:
						return JsonhResult.from_error(escape_sequence_result.error())
					string_builder += escape_sequence_result.value()
			# Literal character
			else:
				string_builder += next

		# Condition: skip remaining steps unless started with multiple quotes
		if start_quote_counter > 1:
			# Pass 1: count leading whitespace -> newline
			var has_leading_whitespace_newline: bool = false
			var leading_whitespace_newline_counter: int = 0
			var sb_index: int = 0
			while sb_index < len(string_builder):
				var next: String = string_builder[sb_index]

				# Newline
				if next in _NEWLINE_CHARS:
					# Join CR LF
					if next == '\r' and sb_index + 1 < len(string_builder) and string_builder[sb_index + 1] == '\n':
						sb_index += 1
					
					has_leading_whitespace_newline = true
					leading_whitespace_newline_counter = sb_index + 1
					break
				# Non-whitespace
				elif next not in _WHITESPACE_CHARS:
					break

				sb_index += 1

			# Condition: skip remaining steps if pass 1 failed
			if has_leading_whitespace_newline:
				# Pass 2: count trailing newline -> whitespace
				var has_trailing_newline_whitespace: bool = false
				var last_newline_index: int = 0
				var trailing_whitespace_counter: int = 0
				var sb_index2: int = 0
				while sb_index2 < len(string_builder):
					var next: String = string_builder[sb_index2]

					# Newline
					if next in _NEWLINE_CHARS:
						has_trailing_newline_whitespace = true
						last_newline_index = sb_index2
						trailing_whitespace_counter = 0

						# Join CR LF
						if next == '\r' and sb_index2 + 1 < len(string_builder) and string_builder[sb_index2 + 1] == '\n':
							sb_index2 += 1
					# Whitespace
					elif next in _WHITESPACE_CHARS:
						trailing_whitespace_counter += 1
					# Non-whitespace
					else:
						has_trailing_newline_whitespace = false
						trailing_whitespace_counter = 0

					sb_index2 += 1

				# Condition: skip remaining steps if pass 2 failed
				if has_trailing_newline_whitespace:
					# Pass 3: strip trailing newline -> whitespace
					string_builder = string_builder.substr(0, last_newline_index)

					# Pass 4: strip leading whitespace -> newline
					string_builder = string_builder.substr(leading_whitespace_newline_counter)

					# Condition: skip remaining steps if no trailing whitespace
					if trailing_whitespace_counter > 0:
						# Pass 5: strip line-leading whitespace
						var is_line_leading_whitespace: bool = true
						var line_leading_whitespace_counter: int = 0
						var sb_index3: int = 0
						while sb_index3 < len(string_builder):
							var next: String = string_builder[sb_index3]

							# Newline
							if next in _NEWLINE_CHARS:
								is_line_leading_whitespace = true
								line_leading_whitespace_counter = 0
							# Whitespace
							elif next in _WHITESPACE_CHARS:
								if is_line_leading_whitespace:
									# Increment line-leading whitespace
									line_leading_whitespace_counter += 1

									# Maximum line-leading whitespace reached
									if line_leading_whitespace_counter == trailing_whitespace_counter:
										# Remove line-leading whitespace
										string_builder = string_builder.substr(0, sb_index3 + 1 - line_leading_whitespace_counter) + string_builder.substr(sb_index3 + 1)
										sb_index3 -= line_leading_whitespace_counter
										# Exit line-leading whitespace
										is_line_leading_whitespace = false
							# Non-whitespace
							else:
								if is_line_leading_whitespace:
									# Remove partial line-leading whitespace
									string_builder = string_builder.substr(0, sb_index3 - line_leading_whitespace_counter) + string_builder.substr(sb_index3)
									sb_index3 -= line_leading_whitespace_counter
									# Exit line-leading whitespace
									is_line_leading_whitespace = false

							sb_index3 += 1

		# End of string
		return JsonhResult.from_value(JsonhToken.new(JsonTokenType.STRING, string_builder))

	func _read_quoteless_string(initial_chars: String = "", is_verbatim: bool = false) -> JsonhResult:
		var is_named_literal_possible: bool = not is_verbatim

		# Read quoteless string
		var string_builder: String = initial_chars

		while true:
			# Peek char
			var next: Variant = _peek()
			if next == null:
				break

			# Escape sequence
			if next == '\\':
				_read()
				if is_verbatim:
					string_builder += next
				else:
					var escape_sequence_result: JsonhResult = _read_escape_sequence()
					if escape_sequence_result.is_error:
						return JsonhResult.from_error(escape_sequence_result.error())
					string_builder += escape_sequence_result.value()
				is_named_literal_possible = false
			# End on reserved character
			elif next in _RESERVED_CHARS():
				break
			# End on newline
			elif next in _NEWLINE_CHARS:
				break
			# Literal character
			else:
				_read()
				string_builder += next

		# Ensure not empty
		if len(string_builder) == 0:
			return JsonhResult.from_error("Empty quoteless string")

		# Trim whitespace
		string_builder = _strip_any(string_builder, _WHITESPACE_CHARS)

		# Match named literal
		if is_named_literal_possible:
			match string_builder:
				"null":
					return JsonhResult.from_value(JsonhToken.new(JsonTokenType.NULL, "null"))
				"true":
					return JsonhResult.from_value(JsonhToken.new(JsonTokenType.TRUE, "true"))
				"false":
					return JsonhResult.from_value(JsonhToken.new(JsonTokenType.FALSE, "false"))

		# End of quoteless string
		return JsonhResult.from_value(JsonhToken.new(JsonTokenType.STRING, string_builder))

	func _detect_quoteless_string() -> Array:
		# Read whitespace
		var whitespace_builder: String = ""

		while true:
			# Read char
			var next: Variant = _peek()
			if next == null:
				break

			# Newline
			if next in _NEWLINE_CHARS:
				# Quoteless strings cannot contain unescaped newlines
				var found_quoteless_string: bool = false
				var whitespace_chars: String = whitespace_builder
				return [found_quoteless_string, whitespace_chars]

			# End of whitespace
			if next not in _WHITESPACE_CHARS:
				break

			# Whitespace
			whitespace_builder += next
			_read()

		# Found quoteless string if found backslash or non-reserved char
		var next_char: Variant = _peek()
		var found_quoteless_string2: bool = next_char != null and (next_char == '\\' or next_char not in _RESERVED_CHARS())
		var whitespace_chars2: String = whitespace_builder
		return [found_quoteless_string2, whitespace_chars2]

	func _read_number() -> Array:
		# Read number
		var number_builder: JsonhRef = JsonhRef.new("")

		# Read sign
		var number_sign: Variant = _read_any('-', '+')
		if number_sign != null:
			number_builder.ref += number_sign

		# Read base
		var base_digits: String = "0123456789"
		var has_base_specifier: bool = false
		var has_leading_zero: bool = false
		if _read_one('0'):
			number_builder.ref += '0'
			has_leading_zero = true

			var hex_base_char: Variant = _read_any('x', 'X')
			if hex_base_char != null:
				number_builder.ref += hex_base_char
				base_digits = "0123456789abcdef"
				has_base_specifier = true
				has_leading_zero = false
			else:
				var binary_base_char: Variant = _read_any('b', 'B')
				if binary_base_char != null:
					number_builder.ref += binary_base_char
					base_digits = "01"
					has_base_specifier = true
					has_leading_zero = false
				else:
					var octal_base_char: Variant = _read_any('o', 'O')
					if octal_base_char != null:
						number_builder.ref += octal_base_char
						base_digits = "01234567"
						has_base_specifier = true
						has_leading_zero = false

		# Read main number
		var main_result: JsonhResult = _read_number_no_exponent(number_builder, base_digits, has_base_specifier, has_leading_zero)
		if main_result.is_error:
			var number: JsonhResult = JsonhResult.from_error(main_result.error())
			var partial_chars_read: String = number_builder.ref
			return [number, partial_chars_read]

		# Possible hexadecimal exponent
		if number_builder.ref[-1] in ['e', 'E']:
			# Read sign (mandatory)
			var exponent_sign: Variant = _read_any('-', '+')
			if exponent_sign != null:
				number_builder.ref += exponent_sign

				# Missing digit between base specifier and exponent (e.g. `0xe+`)
				if has_base_specifier and len(number_builder.ref) == 4:
					var number2: JsonhResult = JsonhResult.from_error("Missing digit between base specifier and exponent")
					var partial_chars_read2: String = number_builder.ref
					return [number2, partial_chars_read2]

				# Read exponent number
				var exponent_result: JsonhResult = _read_number_no_exponent(number_builder, base_digits)
				if exponent_result.is_error:
					var number3: JsonhResult = JsonhResult.from_error(exponent_result.error())
					var partial_chars_read3: String = number_builder.ref
					return [number3, partial_chars_read3]
		# Exponent
		else:
			var exponent_char: Variant = _read_any('e', 'E')
			if exponent_char != null:
				number_builder.ref += exponent_char

				# Read sign
				var exponent_sign: Variant = _read_any('-', '+')
				if exponent_sign != null:
					number_builder.ref += exponent_sign

				# Read exponent number
				var exponent_result: JsonhResult = _read_number_no_exponent(number_builder, base_digits)
				if exponent_result.is_error:
					var number4: JsonhResult = JsonhResult.from_error(exponent_result.error())
					var partial_chars_read4: String = number_builder.ref
					return [number4, partial_chars_read4]

		# End of number
		var number5: JsonhResult = JsonhResult.from_value(JsonhToken.new(JsonTokenType.NUMBER, (number_builder.ref as String)))
		var partial_chars_read5: String = ""
		return [number5, partial_chars_read5]

	func _read_number_no_exponent(number_builder: JsonhRef, base_digits: String, has_base_specifier: bool = false, has_leading_zero: bool = false) -> JsonhResult:
		# Leading underscore
		if (not has_base_specifier) and (not has_leading_zero) and _peek() == '_':
			return JsonhResult.from_error("Leading `_` in number")

		var is_fraction: bool = false
		var is_empty: bool = true

		# Leading zero (not base specifier)
		if has_leading_zero:
			is_empty = false

		while true:
			# Peek char
			var next: Variant = _peek()
			if next == null:
				break

			# Digit
			if (next as String).to_lower() in base_digits:
				_read()
				number_builder.ref += next
				is_empty = false
			# Dot
			elif next == '.':
				# Disallow dot following underscore
				if len(number_builder.ref) >= 1 and number_builder.ref[-1] == '_':
					return JsonhResult.from_error("`.` must not follow `_` in number")

				_read()
				number_builder.ref += next
				is_empty = false

				# Duplicate dot
				if is_fraction:
					return JsonhResult.from_error("Duplicate `.` in number")
				is_fraction = true
			# Underscore
			elif next == '_':
				# Disallow underscore following dot
				if len(number_builder.ref) >= 1 and number_builder.ref[-1] == '.':
					return JsonhResult.from_error("`_` must not follow `.` in number")

				_read()
				number_builder.ref += next
				is_empty = false
			# Other
			else:
				break

		# Ensure not empty
		if is_empty:
			return JsonhResult.from_error("Empty number")

		# Ensure at least one digit
		if not _contains_any_except((number_builder.ref as String), ['.', '-', '+', '_']):
			return JsonhResult.from_error("Number must have at least one digit")

		# Trailing underscore
		if (number_builder.ref as String).ends_with('_'):
			return JsonhResult.from_error("Trailing `_` in number")

		# End of number
		return JsonhResult.from_value()

	func _read_number_or_quoteless_string() -> JsonhResult:
		# Read number
		var read_number_result: Array = _read_number()
		var number: JsonhResult = read_number_result[0]
		var partial_chars_read: String = read_number_result[1]
		if not number.is_error:
			# Try read quoteless string starting with number
			var detect_quoteless_string_result: Array = _detect_quoteless_string()
			var found_quoteless_string: bool = detect_quoteless_string_result[0]
			var whitespace_chars: String = detect_quoteless_string_result[1]
			if found_quoteless_string:
				return _read_quoteless_string((number.value() as JsonhToken).value + whitespace_chars)
			# Otherwise, accept number
			else:
				return number
		# Read quoteless string starting with malformed number
		else:
			return _read_quoteless_string(partial_chars_read)

	func _read_primitive_element() -> JsonhResult:
		# Peek char
		var next: Variant = _peek()
		if next == null:
			return JsonhResult.from_error("Expected primitive element, got end of input")

		# Number
		if len(next) == 1 and ((ord('0') <= ord(next as String) and ord(next as String) <= ord('9')) or ((next as String) in ['-', '+', '.'])):
			return _read_number_or_quoteless_string()
		# String
		elif (next in ['"', '\'']) or (options.supports_version(JsonhVersion.V2) and next == '@'):
			return _read_string()
		# Quoteless string (or named literal)
		else:
			return _read_quoteless_string()

	func _read_comments_and_whitespace() -> JsonhResultEnumerable:
		var enumerable := JsonhResultEnumerableBuilder.new(self)
		
		while true:
			# Whitespace
			_read_whitespace()

			# Peek char
			var next: Variant = _peek()
			if next == null:
				return enumerable.finish(string_index)

			# Comment
			if next in ['#', '/']:
				var comment: JsonhResult = _read_comment()
				if comment.is_error:
					enumerable.append(string_index, comment)
					return enumerable.finish(string_index)
				enumerable.append(string_index, comment)
			# End of comments
			else:
				return enumerable.finish(string_index)
		
		push_error("Unreachable code reached")
		return enumerable.finish(string_index)

	func _read_comment() -> JsonhResult:
		var block_comment: bool = false
		var start_nest_counter: int = 0

		# Hash-style comment
		if _read_one('#'):
			pass
		elif _read_one('/'):
			# Line-style comment
			if _read_one('/'):
				pass
			# Block-style comment
			elif _read_one('*'):
				block_comment = true
			# Nestable block-style comment
			elif options.supports_version(JsonhVersion.V2) and _peek() == '=':
				block_comment = true
				while _read_one('='):
					start_nest_counter += 1
				if not _read_one('*'):
					return JsonhResult.from_error("Expected `*` after start of nesting block comment")
			else:
				return JsonhResult.from_error("Unexpected `/`")
		else:
			return JsonhResult.from_error("Unexpected character")

		# Read comment
		var comment_builder: String = ""

		while true:
			# Read char
			var next: String = _read()

			if block_comment:
				# Error
				if next == null:
					return JsonhResult.from_error("Expected end of block comment, got end of input")
				
				# End of block comment
				if next == '*':
					# End of nestable block comment
					if options.supports_version(JsonhVersion.V2):
						# Count nests
						var end_nest_counter: int = 0
						while end_nest_counter < start_nest_counter and _read_one('='):
							end_nest_counter += 1
						# Partial end nestable block comment was actually part of comment
						if end_nest_counter < start_nest_counter or _peek() != '/':
							comment_builder += '*'
							while end_nest_counter > 0:
								comment_builder += '='
								end_nest_counter -= 1
							continue

					# End of block comment
					if _read_one('/'):
						return JsonhResult.from_value(JsonhToken.new(JsonTokenType.COMMENT, comment_builder))
			else:
				# End of line comment
				if next == null or next in _NEWLINE_CHARS:
					return JsonhResult.from_value(JsonhToken.new(JsonTokenType.COMMENT, comment_builder))

			# Comment char
			comment_builder += next
		
		push_error("Unreachable code reached")
		return JsonhResult.from_error()

	func _read_whitespace() -> void:
		while true:
			# Peek char
			var next: Variant = _peek()
			if next == null:
				return
			
			# Whitespace
			if next in _WHITESPACE_CHARS:
				_read()
			# End of whitespace
			else:
				return

	func _read_hex_sequence(length: int) -> JsonhResult:
		assert(length <= 8)

		var value: int = 0

		for _i: int in range(0, length):
			var next: String = _read()

			# Hex digit
			if next != null and ((ord('0') <= ord(next) and ord(next) <= ord('9')) or (ord('A') <= ord(next) and ord(next) <= ord('F')) or (ord('a') <= ord(next) and ord(next) <= ord('f'))):
				# Get hex digit
				var digit: int = ord(next)
				# Convert hex digit to integer
				var integer: int = \
					digit - ord('A') + 10 if (digit >= ord('A') and digit <= ord('F')) else \
					digit - ord('a') + 10 if (digit >= ord('a') and digit <= ord('f')) else \
					digit - ord('0')
				# Aggregate digit into value
				value = (value * 16) + integer
			# Unexpected char
			else:
				return JsonhResult.from_error("Incorrect number of hexadecimal digits in unicode escape sequence")

		# Return aggregated value
		return JsonhResult.from_value(value)

	func _read_escape_sequence(high_surrogate: Variant = null) -> JsonhResult:
		var escape_char: String = _read()
		if escape_char == null:
			return JsonhResult.from_error("Expected escape sequence, got end of input")

		# Ensure high surrogates are completed
		if high_surrogate != null and escape_char not in ['u', 'x', 'U']:
			return JsonhResult.from_error("Expected low surrogate after high surrogate")

		match escape_char:
			# Reverse solidus
			'\\':
				return JsonhResult.from_value('\\')
			# Backspace
			'b':
				return JsonhResult.from_value('\b')
			# Form feed
			'f':
				return JsonhResult.from_value('\f')
			# Newline
			'n':
				return JsonhResult.from_value('\n')
			# Carriage return
			'r':
				return JsonhResult.from_value('\r')
			# Tab
			't':
				return JsonhResult.from_value('\t')
			# Vertical tab
			'v':
				return JsonhResult.from_value('\v')
			# Null
			'0':
				return JsonhResult.from_value('\uFFFD') # Note: GDScript doesn't support \0 - use replacement char
			# Alert
			'a':
				return JsonhResult.from_value('\a')
			# Escape
			'e':
				return JsonhResult.from_value('\u001b')
			# Unicode hex sequence
			'u':
				return _read_hex_escape_sequence(4, high_surrogate)
			# Short unicode hex sequence
			'x':
				return _read_hex_escape_sequence(2, high_surrogate)
			# Long unicode hex sequence
			'U':
				return _read_hex_escape_sequence(8, high_surrogate)
			# Escaped newline
			_ when escape_char in _NEWLINE_CHARS:
				# Join CR LF
				if escape_char == 'r':
					_read_one('\n')
				return JsonhResult.from_value("")
			# Other
			_:
				return JsonhResult.from_value(escape_char)

	func _read_hex_escape_sequence(length: int, high_surrogate: Variant) -> JsonhResult:
		var code_point: JsonhResult = _read_hex_sequence(length)
		if code_point.is_error:
			return JsonhResult.from_error(code_point.error())

		# Low surrogate
		if high_surrogate != null:
			var combined: JsonhResult = _utf16_surrogates_to_code_point((high_surrogate as int), (code_point.value() as int))
			if combined.is_error:
				return JsonhResult.from_error(combined.error())
			return JsonhResult.from_value(char(combined.value() as int))
		else:
			# High surrogate followed by low surrogate
			if _is_utf16_high_surrogate(code_point.value() as int) and _read_one('\\'):
				return _read_escape_sequence(code_point.value())
			# Standalone character
			else:
				return JsonhResult.from_value(char(code_point.value() as int))

	static func _utf16_surrogates_to_code_point(high_surrogate: int, low_surrogate: int) -> JsonhResult:
		if not JsonhReader._is_utf16_high_surrogate(high_surrogate):
			return JsonhResult.from_error("High surrogate out of range")

		if not JsonhReader._is_utf16_low_surrogate(low_surrogate):
			return JsonhResult.from_error("Low surrogate out of range")

		return JsonhResult.from_value(0x10000 + (((high_surrogate - 0xD800) << 10) | (low_surrogate - 0xDC00)))

	static func _is_utf16_high_surrogate(code_point: int) -> bool:
		return code_point >= 0xD800 and code_point <= 0xDBFF

	static func _is_utf16_low_surrogate(code_point: int) -> bool:
		return code_point >= 0xDC00 and code_point <= 0xDFFF

	func _peek() -> Variant:
		if string_index >= len(string):
			return null
		var next: String = string[string_index]
		return next

	func _read() -> Variant:
		if string_index >= len(string):
			return null
		var next: String = string[string_index]
		string_index += 1
		char_counter += 1
		return next

	func _read_one(char_option: String) -> bool:
		if _peek() == char_option:
			_read()
			return true
		return false

	func _read_any(...char_options: Array) -> Variant:
		# Peek char
		var next: Variant = _peek()
		if next == null:
			return null
		# Match option
		if not (next in char_options):
			return null
		# Option matched
		_read()
		return next

	static func _strip_any(input: String, trim_chars: PackedStringArray) -> String:
		var start: int = 0
		var end: int = len(input)

		while start < end and input[start] in trim_chars:
			start += 1

		while end > start and input[end - 1] in trim_chars:
			end -= 1

		return input.substr(start, end - start)

	static func _contains_any_except(input: String, allowed: PackedStringArray) -> bool:
		for input_char: String in input:
			if input_char not in allowed:
				return true
		return false
