There are different configuration options that control how `dart_mappable` generates code for your
models. Most of the options can be configured on three levels:

- On a **Class Level**, by using its property on the `@MappableClass()` annotation, 
- on a **Library Level**, by using its property on the `@MappableLib()` annotation, or
- on a **Global Level**, by defining its options in the `build.yaml` file (as shown further down).

Class level configurations override library level configurations override global configurations.

## Generation Methods

This package can generate a few different sets of methods, which can be **activated or deactivated**
individually. This makes sure that only code is generated that you actually need.
By default, all methods are generated for each class.

You can set the `generateMethods` property to specify which methods to generate. 
The following methods are supported:

- **decode**: Will generate `fromJson` and `fromMap`.
- **encode**: Will generate `toJson` and `toMap`.
- **copy**: Will generate `copyWith`.
- **stringify**: Will generate the `toString` override.
- **equals**: Will generate the `==` and `hashCode` overrides.

When using **annotations**, you can specify multiple methods using the *bitwise-or* operator like this:
`@MappableClass(generateMethods: GenerateMethods.copy | GenerateMethods.equals | GenerateMethods.stringify)`.

## Case Styles

You can specify the `caseStyle` options for the json keys and the `enumCaseStyle` option for your 
stringified enum values. Choose one of the existing styles or specify a custom one.

Currently supported are:

| Option                | Code                   | Example `myFieldName`            |
|-----------------------|------------------------|----------------------------------|
| `none` / `unmodified` | `CaseStyle.none`       | myFieldName (unchanged, default) |
| `camelCase`           | `CaseStyle.camelCase`  | myFieldName (dart style)         |
| `pascalCase`          | `CaseStyle.pascalCase` | MyFieldName                      |
| `snakeCase`           | `CaseStyle.snakeCase`  | my_field_name                    |
| `paramCase`           | `CaseStyle.paramCase`  | my-field-name                    |
| `lowerCase`           | `CaseStyle.lowerCase`  | myfieldname                      |
| `upperCase`           | `CaseStyle.upperCase`  | MYFIELDNAME                      |

You can also specify a **custom case style** using the `custom(ab,c)` syntax or `CaseStyle()` class.

- The letters before the comma define how to transform each word of a field name. They can be either
  `l` for `lowerCase`, `u` for `upperCase`, or `c` for `capitalCase`. When using only one letter,
  it is applied to all words. When using two letters, the first one is applied to only the first word
  and the second one to all remaining words. Respective options `head` and `tail`.
  
- The one letter after the comma defines the separator between each word, like `_` or `-`. This can
  be any character or empty. Respective option `separator`.

Here are some examples that can be achieved using this syntax:

| Option         | Code                                                                                        | Example `myFieldName` |
|----------------|---------------------------------------------------------------------------------------------|-----------------------|
| `custom(u,_)`  | `CaseStyle(tail: TextTransform.upperCase, separator: '_')`                                  | MY_FIELD_NAME         |
| `custom(uc,+)` | `CaseStyle(head: TextTransform.upperCase, tail: TextTransform.capitalCase, separator: '+')` | MY+Field+Name         |
| `custom(cl,)`  | `CaseStyle(head: TextTransform.capitalCase, tail: TextTransform.lowerCase)`                 | Myfieldname           |

## Global options

Additionally to using the `@MappableClass()` and `@MappableLib()` annotations for configuration,
you can also define a subset of their properties as global options in the `build.yaml` file:

```yaml
global_options:
  dart_mappable_builder:
    options:
      # the case style for the map keys, defaults to 'none'
      caseStyle: none # or 'camelCase', 'snakeCase', etc.
      # the case style for stringified enum values, defaults to 'none'
      enumCaseStyle: none # or 'camelCase', 'snakeCase', etc.
      # if true removes all map keys with null values
      ignoreNull: false # or true
      # used as property name for type discriminators
      discriminatorKey: type
      # used to specify which methods to generate (all by default)
      generateMethods: [decode, encode, copy, stringify, equals]
```

### Global Defaults for Missing Fields

When a required, non-nullable field is missing from the decoded JSON, `dart_mappable` normally throws
a `MapperException`. The **global defaults** feature lets you configure fallback values so that missing
fields are filled in automatically.

Add these options to your `build.yaml`:

```yaml
global_options:
  dart_mappable_builder:
    options:
      # enable global defaults for missing required fields
      useGlobalDefaultsOnMissing: true
      # preferred enum constant name to use as default (optional, defaults to 'none')
      enumFallbackValue: none
      # default values per type
      globalDefaults:
        String: ""
        int: 0
        double: 0.0
        num: 0
        bool: false
        List: []
        Map: {}
```

Or configure per-library using the `@MappableLib` annotation:

```dart
@MappableLib(
  useGlobalDefaultsOnMissing: true,
  enumFallbackValue: 'none',
  globalDefaults: {
    'String': '',
    'int': 0,
    'double': 0.0,
    'bool': false,
  },
)
library;
```

#### How defaults are resolved

For each **required, non-nullable** field without an explicit default:

| Field type | Default value |
|---|---|
| Primitive (`String`, `int`, `double`, `bool`, `num`) | From `globalDefaults` |
| `List`, `Map`, `Set` | From `globalDefaults` |
| Enum | Prefers constant matching `enumFallbackValue` (default: `none`), otherwise first constant |
| `@MappableClass` type | Recursively builds a `const` constructor using defaults for each required param |
| Nullable type | `null` (no config needed) |
| Other types (`DateTime`, `Uri`, etc.) | No default - make these nullable or provide an explicit constructor default |

#### `enumFallbackValue`

Controls which enum constant name is preferred as the default when a required enum field is missing:

```yaml
enumFallbackValue: none     # uses MyEnum.none if it exists, otherwise first constant
enumFallbackValue: unknown  # uses MyEnum.unknown if it exists, otherwise first constant
```

If the specified constant doesn't exist in a particular enum, the first declared constant is used as
the fallback.

#### Example

```dart
enum Status { none, active, inactive }

@MappableClass()
class UserData with UserDataMappable {
  final String name;
  const UserData({required this.name});
}

@MappableClass()
class Order with OrderMappable {
  final String id;
  final Status status;
  final UserData user;
  const Order({required this.id, required this.status, required this.user});
}
```

With the configuration above, decoding incomplete JSON:

```dart
final order = OrderMapper.fromMap({'id': 'ORD-1'});
// order.id == 'ORD-1'                     (from JSON)
// order.status == Status.none              (enum fallback)
// order.user == UserData(name: '')         (recursive const default)
```

Fields that already have explicit defaults in the constructor are not affected - explicit defaults
always take precedence over global defaults.

### `build_extensions`

The `build_extensions` option allows you to specify custom paths for the generated files. This is particularly useful when working with certain code generation scenarios. It takes a map where keys are paths to source files and values are lists of corresponding generated file paths.

#### Example:

Here is an example to write in a build.yaml file to generate the generated files in a `generated` folder:
```yaml
targets:
  $default:
    builders:
      # only to resolve build_runner conflicts
      dart_mappable_builder:
        options:
          build_extensions:
            'lib/{{path}}/{{file}}.dart':
              - 'lib/{{path}}/generated/{{file}}.mapper.dart'
              - 'lib/{{path}}/generated/{{file}}.init.dart'
```

---

<p align="right"><a href="../topics/Copy-With-topic.html">Next: Copy-With</a></p>
