import 'package:analyzer/dart/ast/ast.dart';

import 'package:analyzer/dart/element/element.dart';

import 'package:analyzer/dart/element/type.dart';

import 'package:dart_mappable/dart_mappable.dart';

import '../../utils.dart';

import '../field/mapper_field_element.dart';

import '../mapper_element.dart';

import '../param/mapper_param_element.dart';

import '../param/record_mapper_param_element.dart';

class ClassMapperFieldElement extends MapperFieldElement {

final MapperParamElement? param;

final PropertyInducingElement? field;

final InterfaceMapperElement parent;

ClassMapperFieldElement(this.param, this.field, this.parent)

: assert(param != null || field != null);

@override

late final String name = field?.name ?? param!.name;

@override

late final bool needsGetter =

field != null || param is RecordMapperParamElement;

@override

late final bool needsArg = () {

var isGeneric = resolvedType.accept(IsGenericTypeVisitor());

return isGeneric || (staticArgType != staticArgGetterType);

}();

@override

late final String arg = () {

if (!needsArg) return '';

return ', arg: _arg\$$name';

}();

late final DartType resolvedType = () {

if (field?.enclosingElement is InterfaceElement) {

var it = (parent.element as InterfaceElement).thisType;

it = it.asInstanceOf(field!.enclosingElement as InterfaceElement)!;

var getter = it.getGetter(field!.name ?? '');

return getter!.type.returnType;

}

return field?.type ?? param!.type;

}();

@override

late final String staticGetterType = () {

if (resolvedType is FunctionType) {

return 'Function${resolvedType.isNullable ? '?' : ''}';

}

return parent.parent.prefixedType(resolvedType, resolveBounds: true);

}();

@override

late final String argType = () {

return parent.parent.prefixedType(resolvedType, withNullability: false);

}();

@override

late final String staticArgType = () {

if (resolvedType is FunctionType) {

return 'Function${resolvedType.isNullable ? '?' : ''}';

}

return parent.parent.prefixedType(

param?.type ?? resolvedType,

withNullability: false,

resolveBounds: true,

);

}();

late final String staticArgGetterType = () {

return parent.parent.prefixedType(

resolvedType,

withNullability: false,

resolveBounds: true,

);

}();

late bool isAnnotated =

(field != null && fieldChecker.hasAnnotationOf(field!)) ||

(field?.getter != null && fieldChecker.hasAnnotationOf(field!.getter!));

@override

late String mode = () {

if (param == null && field != null && !isAnnotated) {

return ', mode: FieldMode.member';

} else if (param != null && param!.accessor is! FieldElement) {

return ', mode: FieldMode.param';

} else {

return '';

}

}();

@override

late final String key = () {

String? key;

if (param case var p?) {

key = p.key ?? parent.caseStyle.transform(p.name);

}

key ??=

_keyFor(field) ??

_keyFor(field?.getter) ??

parent.caseStyle.transform(name);

if (key != name) {

return ", key: r'$key'";

} else {

return '';

}

}();

@override

late final String opt = (param?.isOptional ?? false) ? ', opt: true' : '';

@override

late final Future<String> def = () async {

String? defaultValue;

if (param != null) {

var p = param!.parameter;

if (p != null) {

var node = await p.getResolvedNode();

if (node is DefaultFormalParameter &&

node.defaultValue.toString() != 'null') {

if (node.defaultValue case SimpleIdentifier(

element: PropertyAccessorElement(enclosingElement: ClassElement clazz),

name: String name,

)) {

defaultValue = '${clazz.name}.$name';

} else {

defaultValue = node.defaultValue?.toSource();

}

} else if (p.hasDefaultValue && p.defaultValueCode != 'null') {

defaultValue = p.defaultValueCode;

}

}

}

if (defaultValue == null &&

parent.options.useGlobalDefaultsOnMissing == true &&

!resolvedType.isNullable &&

!(param?.isOptional ?? false)) {

var defaults = parent.options.globalDefaults;

if (defaults != null) {

defaultValue = _resolveDefaultForType(resolvedType, defaults);

}

}

return defaultValue != null ? ', def: $defaultValue' : '';

}();

String? _resolveDefaultForType(DartType type, Map<String, dynamic> defaults) {

var typeName = type.getDisplayString();

if (defaults.containsKey(typeName)) {

return _formatValue(defaults[typeName]);

}

if (type is InterfaceType) {

if (type.element.name == 'List' && type.element.library.isDartCore) {

return defaults.containsKey('List') ? _formatValue(defaults['List']) : null;

} else if (type.element.name == 'Map' && type.element.library.isDartCore) {

return defaults.containsKey('Map') ? _formatValue(defaults['Map']) : null;

} else if (type.element.name == 'Set' && type.element.library.isDartCore) {

return defaults.containsKey('Set') ? _formatValue(defaults['Set']) : null;

} else if (classChecker.hasAnnotationOf(type.element)) {

return _buildCustomClassDefault(type, defaults);

} else if (type.element is EnumElement) {

return _buildEnumDefault(type);

}

}

return null;

}

String? _buildCustomClassDefault(

InterfaceType type, Map<String, dynamic> defaults) {

var element = type.element;

// Find the unnamed constructor

ConstructorElement? ctor;

if (element is ClassElement) {

ctor = element.unnamedConstructor;

}

if (ctor == null) return null;
if (!ctor.isConst) return null;

var args = <String>[];

for (var param in ctor.formalParameters) {

var paramType = param.type;

if (paramType.isNullable || (!param.isRequired && param.isOptional)) {

// Skip nullable/optional params — they default to null

continue;

}

var value = _resolveDefaultForType(paramType, defaults);

if (value == null) {

// Can't produce a default for a required param — give up

return null;

}

if (param.isNamed) {

args.add('${param.name}: $value');

} else {

args.add(value);

}

}

var className = parent.parent.prefixedType(type, withNullability: false);

return 'const $className(${args.join(', ')})';

}

String? _buildEnumDefault(InterfaceType type) {

var element = type.element;

if (element is! EnumElement) return null;

var constants = element.fields.where((f) => f.isEnumConstant).toList();

if (constants.isEmpty) return null;

var className = parent.parent.prefixedType(type, withNullability: false);

// Priority 1: Check enumKeyMissingDefaultValue from global config.
var fallbackName = parent.options.enumKeyMissingDefaultValue;
if (fallbackName != null) {
  var preferredConstant = constants.where((f) => f.name == fallbackName).firstOrNull;
  if (preferredConstant != null) {
    return '$className.${preferredConstant.name}';
  }
}

// Priority 2: Check @MappableEnum(defaultValue: ...) annotation on the enum itself.
var annotation = enumChecker.firstAnnotationOf(element);
if (annotation != null) {
  var defaultValueObj = annotation.getField('defaultValue');
  if (defaultValueObj != null && !defaultValueObj.isNull) {
    var index = defaultValueObj.getField('index')?.toIntValue();
    if (index != null && index < constants.length) {
      return '$className.${constants[index].name}';
    }
  }
}

// No default available — do not fall back to first enum value.
return null;

}

String _formatValue(dynamic val) {

if (val is String) {

return "r'$val'";

} else if (val is List) {

return '[${val.map(_formatValue).join(', ')}]';

} else if (val is Map) {

return '{${val.entries.map((e) => "${_formatValue(e.key)}: ${_formatValue(e.value)}").join(', ')}}';

} else {

return val.toString();

}

}

@override

late final Future<String> hook = () async {

var hook =

(await param?.getHook()) ??

(await hookFor(field)) ??

(await hookFor(field?.getter));

return hook != null ? ', hook: $hook' : '';

}();

}

String? _keyFor(Element? element) {

if (element == null) {

return null;

}

return fieldChecker

.firstAnnotationOf(element)

?.getField('key')!

.toStringValue();

}