// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_drift_database.dart';

// ignore_for_file: type=lint
class $SourceRecordsTable extends SourceRecords
    with TableInfo<$SourceRecordsTable, SourceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookSourceUrlMeta =
      const VerificationMeta('bookSourceUrl');
  @override
  late final GeneratedColumn<String> bookSourceUrl = GeneratedColumn<String>(
      'book_source_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookSourceNameMeta =
      const VerificationMeta('bookSourceName');
  @override
  late final GeneratedColumn<String> bookSourceName = GeneratedColumn<String>(
      'book_source_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _bookSourceGroupMeta =
      const VerificationMeta('bookSourceGroup');
  @override
  late final GeneratedColumn<String> bookSourceGroup = GeneratedColumn<String>(
      'book_source_group', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bookSourceTypeMeta =
      const VerificationMeta('bookSourceType');
  @override
  late final GeneratedColumn<int> bookSourceType = GeneratedColumn<int>(
      'book_source_type', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _enabledExploreMeta =
      const VerificationMeta('enabledExplore');
  @override
  late final GeneratedColumn<bool> enabledExplore = GeneratedColumn<bool>(
      'enabled_explore', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("enabled_explore" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _enabledCookieJarMeta =
      const VerificationMeta('enabledCookieJar');
  @override
  late final GeneratedColumn<bool> enabledCookieJar = GeneratedColumn<bool>(
      'enabled_cookie_jar', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("enabled_cookie_jar" IN (0, 1))'));
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<int> weight = GeneratedColumn<int>(
      'weight', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _customOrderMeta =
      const VerificationMeta('customOrder');
  @override
  late final GeneratedColumn<int> customOrder = GeneratedColumn<int>(
      'custom_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _respondTimeMeta =
      const VerificationMeta('respondTime');
  @override
  late final GeneratedColumn<int> respondTime = GeneratedColumn<int>(
      'respond_time', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(180000));
  static const VerificationMeta _headerMeta = const VerificationMeta('header');
  @override
  late final GeneratedColumn<String> header = GeneratedColumn<String>(
      'header', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _loginUrlMeta =
      const VerificationMeta('loginUrl');
  @override
  late final GeneratedColumn<String> loginUrl = GeneratedColumn<String>(
      'login_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bookSourceCommentMeta =
      const VerificationMeta('bookSourceComment');
  @override
  late final GeneratedColumn<String> bookSourceComment =
      GeneratedColumn<String>('book_source_comment', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastUpdateTimeMeta =
      const VerificationMeta('lastUpdateTime');
  @override
  late final GeneratedColumn<int> lastUpdateTime = GeneratedColumn<int>(
      'last_update_time', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _rawJsonMeta =
      const VerificationMeta('rawJson');
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
      'raw_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        bookSourceUrl,
        bookSourceName,
        bookSourceGroup,
        bookSourceType,
        enabled,
        enabledExplore,
        enabledCookieJar,
        weight,
        customOrder,
        respondTime,
        header,
        loginUrl,
        bookSourceComment,
        lastUpdateTime,
        rawJson,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_records';
  @override
  VerificationContext validateIntegrity(Insertable<SourceRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_source_url')) {
      context.handle(
          _bookSourceUrlMeta,
          bookSourceUrl.isAcceptableOrUnknown(
              data['book_source_url']!, _bookSourceUrlMeta));
    } else if (isInserting) {
      context.missing(_bookSourceUrlMeta);
    }
    if (data.containsKey('book_source_name')) {
      context.handle(
          _bookSourceNameMeta,
          bookSourceName.isAcceptableOrUnknown(
              data['book_source_name']!, _bookSourceNameMeta));
    }
    if (data.containsKey('book_source_group')) {
      context.handle(
          _bookSourceGroupMeta,
          bookSourceGroup.isAcceptableOrUnknown(
              data['book_source_group']!, _bookSourceGroupMeta));
    }
    if (data.containsKey('book_source_type')) {
      context.handle(
          _bookSourceTypeMeta,
          bookSourceType.isAcceptableOrUnknown(
              data['book_source_type']!, _bookSourceTypeMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('enabled_explore')) {
      context.handle(
          _enabledExploreMeta,
          enabledExplore.isAcceptableOrUnknown(
              data['enabled_explore']!, _enabledExploreMeta));
    }
    if (data.containsKey('enabled_cookie_jar')) {
      context.handle(
          _enabledCookieJarMeta,
          enabledCookieJar.isAcceptableOrUnknown(
              data['enabled_cookie_jar']!, _enabledCookieJarMeta));
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta,
          weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    }
    if (data.containsKey('custom_order')) {
      context.handle(
          _customOrderMeta,
          customOrder.isAcceptableOrUnknown(
              data['custom_order']!, _customOrderMeta));
    }
    if (data.containsKey('respond_time')) {
      context.handle(
          _respondTimeMeta,
          respondTime.isAcceptableOrUnknown(
              data['respond_time']!, _respondTimeMeta));
    }
    if (data.containsKey('header')) {
      context.handle(_headerMeta,
          header.isAcceptableOrUnknown(data['header']!, _headerMeta));
    }
    if (data.containsKey('login_url')) {
      context.handle(_loginUrlMeta,
          loginUrl.isAcceptableOrUnknown(data['login_url']!, _loginUrlMeta));
    }
    if (data.containsKey('book_source_comment')) {
      context.handle(
          _bookSourceCommentMeta,
          bookSourceComment.isAcceptableOrUnknown(
              data['book_source_comment']!, _bookSourceCommentMeta));
    }
    if (data.containsKey('last_update_time')) {
      context.handle(
          _lastUpdateTimeMeta,
          lastUpdateTime.isAcceptableOrUnknown(
              data['last_update_time']!, _lastUpdateTimeMeta));
    }
    if (data.containsKey('raw_json')) {
      context.handle(_rawJsonMeta,
          rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookSourceUrl};
  @override
  SourceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceRecord(
      bookSourceUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}book_source_url'])!,
      bookSourceName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}book_source_name'])!,
      bookSourceGroup: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}book_source_group']),
      bookSourceType: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_source_type'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      enabledExplore: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled_explore'])!,
      enabledCookieJar: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}enabled_cookie_jar']),
      weight: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}weight'])!,
      customOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}custom_order'])!,
      respondTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}respond_time'])!,
      header: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}header']),
      loginUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}login_url']),
      bookSourceComment: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}book_source_comment']),
      lastUpdateTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_update_time'])!,
      rawJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_json']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SourceRecordsTable createAlias(String alias) {
    return $SourceRecordsTable(attachedDatabase, alias);
  }
}

class SourceRecord extends DataClass implements Insertable<SourceRecord> {
  final String bookSourceUrl;
  final String bookSourceName;
  final String? bookSourceGroup;
  final int bookSourceType;
  final bool enabled;
  final bool enabledExplore;
  final bool? enabledCookieJar;
  final int weight;
  final int customOrder;
  final int respondTime;
  final String? header;
  final String? loginUrl;
  final String? bookSourceComment;
  final int lastUpdateTime;
  final String? rawJson;
  final int updatedAt;
  const SourceRecord(
      {required this.bookSourceUrl,
      required this.bookSourceName,
      this.bookSourceGroup,
      required this.bookSourceType,
      required this.enabled,
      required this.enabledExplore,
      this.enabledCookieJar,
      required this.weight,
      required this.customOrder,
      required this.respondTime,
      this.header,
      this.loginUrl,
      this.bookSourceComment,
      required this.lastUpdateTime,
      this.rawJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_source_url'] = Variable<String>(bookSourceUrl);
    map['book_source_name'] = Variable<String>(bookSourceName);
    if (!nullToAbsent || bookSourceGroup != null) {
      map['book_source_group'] = Variable<String>(bookSourceGroup);
    }
    map['book_source_type'] = Variable<int>(bookSourceType);
    map['enabled'] = Variable<bool>(enabled);
    map['enabled_explore'] = Variable<bool>(enabledExplore);
    if (!nullToAbsent || enabledCookieJar != null) {
      map['enabled_cookie_jar'] = Variable<bool>(enabledCookieJar);
    }
    map['weight'] = Variable<int>(weight);
    map['custom_order'] = Variable<int>(customOrder);
    map['respond_time'] = Variable<int>(respondTime);
    if (!nullToAbsent || header != null) {
      map['header'] = Variable<String>(header);
    }
    if (!nullToAbsent || loginUrl != null) {
      map['login_url'] = Variable<String>(loginUrl);
    }
    if (!nullToAbsent || bookSourceComment != null) {
      map['book_source_comment'] = Variable<String>(bookSourceComment);
    }
    map['last_update_time'] = Variable<int>(lastUpdateTime);
    if (!nullToAbsent || rawJson != null) {
      map['raw_json'] = Variable<String>(rawJson);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SourceRecordsCompanion toCompanion(bool nullToAbsent) {
    return SourceRecordsCompanion(
      bookSourceUrl: Value(bookSourceUrl),
      bookSourceName: Value(bookSourceName),
      bookSourceGroup: bookSourceGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(bookSourceGroup),
      bookSourceType: Value(bookSourceType),
      enabled: Value(enabled),
      enabledExplore: Value(enabledExplore),
      enabledCookieJar: enabledCookieJar == null && nullToAbsent
          ? const Value.absent()
          : Value(enabledCookieJar),
      weight: Value(weight),
      customOrder: Value(customOrder),
      respondTime: Value(respondTime),
      header:
          header == null && nullToAbsent ? const Value.absent() : Value(header),
      loginUrl: loginUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(loginUrl),
      bookSourceComment: bookSourceComment == null && nullToAbsent
          ? const Value.absent()
          : Value(bookSourceComment),
      lastUpdateTime: Value(lastUpdateTime),
      rawJson: rawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory SourceRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceRecord(
      bookSourceUrl: serializer.fromJson<String>(json['bookSourceUrl']),
      bookSourceName: serializer.fromJson<String>(json['bookSourceName']),
      bookSourceGroup: serializer.fromJson<String?>(json['bookSourceGroup']),
      bookSourceType: serializer.fromJson<int>(json['bookSourceType']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      enabledExplore: serializer.fromJson<bool>(json['enabledExplore']),
      enabledCookieJar: serializer.fromJson<bool?>(json['enabledCookieJar']),
      weight: serializer.fromJson<int>(json['weight']),
      customOrder: serializer.fromJson<int>(json['customOrder']),
      respondTime: serializer.fromJson<int>(json['respondTime']),
      header: serializer.fromJson<String?>(json['header']),
      loginUrl: serializer.fromJson<String?>(json['loginUrl']),
      bookSourceComment:
          serializer.fromJson<String?>(json['bookSourceComment']),
      lastUpdateTime: serializer.fromJson<int>(json['lastUpdateTime']),
      rawJson: serializer.fromJson<String?>(json['rawJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookSourceUrl': serializer.toJson<String>(bookSourceUrl),
      'bookSourceName': serializer.toJson<String>(bookSourceName),
      'bookSourceGroup': serializer.toJson<String?>(bookSourceGroup),
      'bookSourceType': serializer.toJson<int>(bookSourceType),
      'enabled': serializer.toJson<bool>(enabled),
      'enabledExplore': serializer.toJson<bool>(enabledExplore),
      'enabledCookieJar': serializer.toJson<bool?>(enabledCookieJar),
      'weight': serializer.toJson<int>(weight),
      'customOrder': serializer.toJson<int>(customOrder),
      'respondTime': serializer.toJson<int>(respondTime),
      'header': serializer.toJson<String?>(header),
      'loginUrl': serializer.toJson<String?>(loginUrl),
      'bookSourceComment': serializer.toJson<String?>(bookSourceComment),
      'lastUpdateTime': serializer.toJson<int>(lastUpdateTime),
      'rawJson': serializer.toJson<String?>(rawJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SourceRecord copyWith(
          {String? bookSourceUrl,
          String? bookSourceName,
          Value<String?> bookSourceGroup = const Value.absent(),
          int? bookSourceType,
          bool? enabled,
          bool? enabledExplore,
          Value<bool?> enabledCookieJar = const Value.absent(),
          int? weight,
          int? customOrder,
          int? respondTime,
          Value<String?> header = const Value.absent(),
          Value<String?> loginUrl = const Value.absent(),
          Value<String?> bookSourceComment = const Value.absent(),
          int? lastUpdateTime,
          Value<String?> rawJson = const Value.absent(),
          int? updatedAt}) =>
      SourceRecord(
        bookSourceUrl: bookSourceUrl ?? this.bookSourceUrl,
        bookSourceName: bookSourceName ?? this.bookSourceName,
        bookSourceGroup: bookSourceGroup.present
            ? bookSourceGroup.value
            : this.bookSourceGroup,
        bookSourceType: bookSourceType ?? this.bookSourceType,
        enabled: enabled ?? this.enabled,
        enabledExplore: enabledExplore ?? this.enabledExplore,
        enabledCookieJar: enabledCookieJar.present
            ? enabledCookieJar.value
            : this.enabledCookieJar,
        weight: weight ?? this.weight,
        customOrder: customOrder ?? this.customOrder,
        respondTime: respondTime ?? this.respondTime,
        header: header.present ? header.value : this.header,
        loginUrl: loginUrl.present ? loginUrl.value : this.loginUrl,
        bookSourceComment: bookSourceComment.present
            ? bookSourceComment.value
            : this.bookSourceComment,
        lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
        rawJson: rawJson.present ? rawJson.value : this.rawJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SourceRecord copyWithCompanion(SourceRecordsCompanion data) {
    return SourceRecord(
      bookSourceUrl: data.bookSourceUrl.present
          ? data.bookSourceUrl.value
          : this.bookSourceUrl,
      bookSourceName: data.bookSourceName.present
          ? data.bookSourceName.value
          : this.bookSourceName,
      bookSourceGroup: data.bookSourceGroup.present
          ? data.bookSourceGroup.value
          : this.bookSourceGroup,
      bookSourceType: data.bookSourceType.present
          ? data.bookSourceType.value
          : this.bookSourceType,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      enabledExplore: data.enabledExplore.present
          ? data.enabledExplore.value
          : this.enabledExplore,
      enabledCookieJar: data.enabledCookieJar.present
          ? data.enabledCookieJar.value
          : this.enabledCookieJar,
      weight: data.weight.present ? data.weight.value : this.weight,
      customOrder:
          data.customOrder.present ? data.customOrder.value : this.customOrder,
      respondTime:
          data.respondTime.present ? data.respondTime.value : this.respondTime,
      header: data.header.present ? data.header.value : this.header,
      loginUrl: data.loginUrl.present ? data.loginUrl.value : this.loginUrl,
      bookSourceComment: data.bookSourceComment.present
          ? data.bookSourceComment.value
          : this.bookSourceComment,
      lastUpdateTime: data.lastUpdateTime.present
          ? data.lastUpdateTime.value
          : this.lastUpdateTime,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceRecord(')
          ..write('bookSourceUrl: $bookSourceUrl, ')
          ..write('bookSourceName: $bookSourceName, ')
          ..write('bookSourceGroup: $bookSourceGroup, ')
          ..write('bookSourceType: $bookSourceType, ')
          ..write('enabled: $enabled, ')
          ..write('enabledExplore: $enabledExplore, ')
          ..write('enabledCookieJar: $enabledCookieJar, ')
          ..write('weight: $weight, ')
          ..write('customOrder: $customOrder, ')
          ..write('respondTime: $respondTime, ')
          ..write('header: $header, ')
          ..write('loginUrl: $loginUrl, ')
          ..write('bookSourceComment: $bookSourceComment, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('rawJson: $rawJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      bookSourceUrl,
      bookSourceName,
      bookSourceGroup,
      bookSourceType,
      enabled,
      enabledExplore,
      enabledCookieJar,
      weight,
      customOrder,
      respondTime,
      header,
      loginUrl,
      bookSourceComment,
      lastUpdateTime,
      rawJson,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceRecord &&
          other.bookSourceUrl == this.bookSourceUrl &&
          other.bookSourceName == this.bookSourceName &&
          other.bookSourceGroup == this.bookSourceGroup &&
          other.bookSourceType == this.bookSourceType &&
          other.enabled == this.enabled &&
          other.enabledExplore == this.enabledExplore &&
          other.enabledCookieJar == this.enabledCookieJar &&
          other.weight == this.weight &&
          other.customOrder == this.customOrder &&
          other.respondTime == this.respondTime &&
          other.header == this.header &&
          other.loginUrl == this.loginUrl &&
          other.bookSourceComment == this.bookSourceComment &&
          other.lastUpdateTime == this.lastUpdateTime &&
          other.rawJson == this.rawJson &&
          other.updatedAt == this.updatedAt);
}

class SourceRecordsCompanion extends UpdateCompanion<SourceRecord> {
  final Value<String> bookSourceUrl;
  final Value<String> bookSourceName;
  final Value<String?> bookSourceGroup;
  final Value<int> bookSourceType;
  final Value<bool> enabled;
  final Value<bool> enabledExplore;
  final Value<bool?> enabledCookieJar;
  final Value<int> weight;
  final Value<int> customOrder;
  final Value<int> respondTime;
  final Value<String?> header;
  final Value<String?> loginUrl;
  final Value<String?> bookSourceComment;
  final Value<int> lastUpdateTime;
  final Value<String?> rawJson;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SourceRecordsCompanion({
    this.bookSourceUrl = const Value.absent(),
    this.bookSourceName = const Value.absent(),
    this.bookSourceGroup = const Value.absent(),
    this.bookSourceType = const Value.absent(),
    this.enabled = const Value.absent(),
    this.enabledExplore = const Value.absent(),
    this.enabledCookieJar = const Value.absent(),
    this.weight = const Value.absent(),
    this.customOrder = const Value.absent(),
    this.respondTime = const Value.absent(),
    this.header = const Value.absent(),
    this.loginUrl = const Value.absent(),
    this.bookSourceComment = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceRecordsCompanion.insert({
    required String bookSourceUrl,
    this.bookSourceName = const Value.absent(),
    this.bookSourceGroup = const Value.absent(),
    this.bookSourceType = const Value.absent(),
    this.enabled = const Value.absent(),
    this.enabledExplore = const Value.absent(),
    this.enabledCookieJar = const Value.absent(),
    this.weight = const Value.absent(),
    this.customOrder = const Value.absent(),
    this.respondTime = const Value.absent(),
    this.header = const Value.absent(),
    this.loginUrl = const Value.absent(),
    this.bookSourceComment = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookSourceUrl = Value(bookSourceUrl);
  static Insertable<SourceRecord> custom({
    Expression<String>? bookSourceUrl,
    Expression<String>? bookSourceName,
    Expression<String>? bookSourceGroup,
    Expression<int>? bookSourceType,
    Expression<bool>? enabled,
    Expression<bool>? enabledExplore,
    Expression<bool>? enabledCookieJar,
    Expression<int>? weight,
    Expression<int>? customOrder,
    Expression<int>? respondTime,
    Expression<String>? header,
    Expression<String>? loginUrl,
    Expression<String>? bookSourceComment,
    Expression<int>? lastUpdateTime,
    Expression<String>? rawJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookSourceUrl != null) 'book_source_url': bookSourceUrl,
      if (bookSourceName != null) 'book_source_name': bookSourceName,
      if (bookSourceGroup != null) 'book_source_group': bookSourceGroup,
      if (bookSourceType != null) 'book_source_type': bookSourceType,
      if (enabled != null) 'enabled': enabled,
      if (enabledExplore != null) 'enabled_explore': enabledExplore,
      if (enabledCookieJar != null) 'enabled_cookie_jar': enabledCookieJar,
      if (weight != null) 'weight': weight,
      if (customOrder != null) 'custom_order': customOrder,
      if (respondTime != null) 'respond_time': respondTime,
      if (header != null) 'header': header,
      if (loginUrl != null) 'login_url': loginUrl,
      if (bookSourceComment != null) 'book_source_comment': bookSourceComment,
      if (lastUpdateTime != null) 'last_update_time': lastUpdateTime,
      if (rawJson != null) 'raw_json': rawJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceRecordsCompanion copyWith(
      {Value<String>? bookSourceUrl,
      Value<String>? bookSourceName,
      Value<String?>? bookSourceGroup,
      Value<int>? bookSourceType,
      Value<bool>? enabled,
      Value<bool>? enabledExplore,
      Value<bool?>? enabledCookieJar,
      Value<int>? weight,
      Value<int>? customOrder,
      Value<int>? respondTime,
      Value<String?>? header,
      Value<String?>? loginUrl,
      Value<String?>? bookSourceComment,
      Value<int>? lastUpdateTime,
      Value<String?>? rawJson,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return SourceRecordsCompanion(
      bookSourceUrl: bookSourceUrl ?? this.bookSourceUrl,
      bookSourceName: bookSourceName ?? this.bookSourceName,
      bookSourceGroup: bookSourceGroup ?? this.bookSourceGroup,
      bookSourceType: bookSourceType ?? this.bookSourceType,
      enabled: enabled ?? this.enabled,
      enabledExplore: enabledExplore ?? this.enabledExplore,
      enabledCookieJar: enabledCookieJar ?? this.enabledCookieJar,
      weight: weight ?? this.weight,
      customOrder: customOrder ?? this.customOrder,
      respondTime: respondTime ?? this.respondTime,
      header: header ?? this.header,
      loginUrl: loginUrl ?? this.loginUrl,
      bookSourceComment: bookSourceComment ?? this.bookSourceComment,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      rawJson: rawJson ?? this.rawJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookSourceUrl.present) {
      map['book_source_url'] = Variable<String>(bookSourceUrl.value);
    }
    if (bookSourceName.present) {
      map['book_source_name'] = Variable<String>(bookSourceName.value);
    }
    if (bookSourceGroup.present) {
      map['book_source_group'] = Variable<String>(bookSourceGroup.value);
    }
    if (bookSourceType.present) {
      map['book_source_type'] = Variable<int>(bookSourceType.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (enabledExplore.present) {
      map['enabled_explore'] = Variable<bool>(enabledExplore.value);
    }
    if (enabledCookieJar.present) {
      map['enabled_cookie_jar'] = Variable<bool>(enabledCookieJar.value);
    }
    if (weight.present) {
      map['weight'] = Variable<int>(weight.value);
    }
    if (customOrder.present) {
      map['custom_order'] = Variable<int>(customOrder.value);
    }
    if (respondTime.present) {
      map['respond_time'] = Variable<int>(respondTime.value);
    }
    if (header.present) {
      map['header'] = Variable<String>(header.value);
    }
    if (loginUrl.present) {
      map['login_url'] = Variable<String>(loginUrl.value);
    }
    if (bookSourceComment.present) {
      map['book_source_comment'] = Variable<String>(bookSourceComment.value);
    }
    if (lastUpdateTime.present) {
      map['last_update_time'] = Variable<int>(lastUpdateTime.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceRecordsCompanion(')
          ..write('bookSourceUrl: $bookSourceUrl, ')
          ..write('bookSourceName: $bookSourceName, ')
          ..write('bookSourceGroup: $bookSourceGroup, ')
          ..write('bookSourceType: $bookSourceType, ')
          ..write('enabled: $enabled, ')
          ..write('enabledExplore: $enabledExplore, ')
          ..write('enabledCookieJar: $enabledCookieJar, ')
          ..write('weight: $weight, ')
          ..write('customOrder: $customOrder, ')
          ..write('respondTime: $respondTime, ')
          ..write('header: $header, ')
          ..write('loginUrl: $loginUrl, ')
          ..write('bookSourceComment: $bookSourceComment, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('rawJson: $rawJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SourceDriftDatabase extends GeneratedDatabase {
  _$SourceDriftDatabase(QueryExecutor e) : super(e);
  $SourceDriftDatabaseManager get managers => $SourceDriftDatabaseManager(this);
  late final $SourceRecordsTable sourceRecords = $SourceRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [sourceRecords];
}

typedef $$SourceRecordsTableCreateCompanionBuilder = SourceRecordsCompanion
    Function({
  required String bookSourceUrl,
  Value<String> bookSourceName,
  Value<String?> bookSourceGroup,
  Value<int> bookSourceType,
  Value<bool> enabled,
  Value<bool> enabledExplore,
  Value<bool?> enabledCookieJar,
  Value<int> weight,
  Value<int> customOrder,
  Value<int> respondTime,
  Value<String?> header,
  Value<String?> loginUrl,
  Value<String?> bookSourceComment,
  Value<int> lastUpdateTime,
  Value<String?> rawJson,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$SourceRecordsTableUpdateCompanionBuilder = SourceRecordsCompanion
    Function({
  Value<String> bookSourceUrl,
  Value<String> bookSourceName,
  Value<String?> bookSourceGroup,
  Value<int> bookSourceType,
  Value<bool> enabled,
  Value<bool> enabledExplore,
  Value<bool?> enabledCookieJar,
  Value<int> weight,
  Value<int> customOrder,
  Value<int> respondTime,
  Value<String?> header,
  Value<String?> loginUrl,
  Value<String?> bookSourceComment,
  Value<int> lastUpdateTime,
  Value<String?> rawJson,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$SourceRecordsTableFilterComposer
    extends Composer<_$SourceDriftDatabase, $SourceRecordsTable> {
  $$SourceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookSourceUrl => $composableBuilder(
      column: $table.bookSourceUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookSourceName => $composableBuilder(
      column: $table.bookSourceName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookSourceGroup => $composableBuilder(
      column: $table.bookSourceGroup,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bookSourceType => $composableBuilder(
      column: $table.bookSourceType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabledExplore => $composableBuilder(
      column: $table.enabledExplore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabledCookieJar => $composableBuilder(
      column: $table.enabledCookieJar,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get customOrder => $composableBuilder(
      column: $table.customOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get respondTime => $composableBuilder(
      column: $table.respondTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get header => $composableBuilder(
      column: $table.header, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get loginUrl => $composableBuilder(
      column: $table.loginUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookSourceComment => $composableBuilder(
      column: $table.bookSourceComment,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastUpdateTime => $composableBuilder(
      column: $table.lastUpdateTime,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawJson => $composableBuilder(
      column: $table.rawJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SourceRecordsTableOrderingComposer
    extends Composer<_$SourceDriftDatabase, $SourceRecordsTable> {
  $$SourceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookSourceUrl => $composableBuilder(
      column: $table.bookSourceUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookSourceName => $composableBuilder(
      column: $table.bookSourceName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookSourceGroup => $composableBuilder(
      column: $table.bookSourceGroup,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bookSourceType => $composableBuilder(
      column: $table.bookSourceType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabledExplore => $composableBuilder(
      column: $table.enabledExplore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabledCookieJar => $composableBuilder(
      column: $table.enabledCookieJar,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get customOrder => $composableBuilder(
      column: $table.customOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get respondTime => $composableBuilder(
      column: $table.respondTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get header => $composableBuilder(
      column: $table.header, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get loginUrl => $composableBuilder(
      column: $table.loginUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookSourceComment => $composableBuilder(
      column: $table.bookSourceComment,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastUpdateTime => $composableBuilder(
      column: $table.lastUpdateTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawJson => $composableBuilder(
      column: $table.rawJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SourceRecordsTableAnnotationComposer
    extends Composer<_$SourceDriftDatabase, $SourceRecordsTable> {
  $$SourceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookSourceUrl => $composableBuilder(
      column: $table.bookSourceUrl, builder: (column) => column);

  GeneratedColumn<String> get bookSourceName => $composableBuilder(
      column: $table.bookSourceName, builder: (column) => column);

  GeneratedColumn<String> get bookSourceGroup => $composableBuilder(
      column: $table.bookSourceGroup, builder: (column) => column);

  GeneratedColumn<int> get bookSourceType => $composableBuilder(
      column: $table.bookSourceType, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get enabledExplore => $composableBuilder(
      column: $table.enabledExplore, builder: (column) => column);

  GeneratedColumn<bool> get enabledCookieJar => $composableBuilder(
      column: $table.enabledCookieJar, builder: (column) => column);

  GeneratedColumn<int> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get customOrder => $composableBuilder(
      column: $table.customOrder, builder: (column) => column);

  GeneratedColumn<int> get respondTime => $composableBuilder(
      column: $table.respondTime, builder: (column) => column);

  GeneratedColumn<String> get header =>
      $composableBuilder(column: $table.header, builder: (column) => column);

  GeneratedColumn<String> get loginUrl =>
      $composableBuilder(column: $table.loginUrl, builder: (column) => column);

  GeneratedColumn<String> get bookSourceComment => $composableBuilder(
      column: $table.bookSourceComment, builder: (column) => column);

  GeneratedColumn<int> get lastUpdateTime => $composableBuilder(
      column: $table.lastUpdateTime, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SourceRecordsTableTableManager extends RootTableManager<
    _$SourceDriftDatabase,
    $SourceRecordsTable,
    SourceRecord,
    $$SourceRecordsTableFilterComposer,
    $$SourceRecordsTableOrderingComposer,
    $$SourceRecordsTableAnnotationComposer,
    $$SourceRecordsTableCreateCompanionBuilder,
    $$SourceRecordsTableUpdateCompanionBuilder,
    (
      SourceRecord,
      BaseReferences<_$SourceDriftDatabase, $SourceRecordsTable, SourceRecord>
    ),
    SourceRecord,
    PrefetchHooks Function()> {
  $$SourceRecordsTableTableManager(
      _$SourceDriftDatabase db, $SourceRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> bookSourceUrl = const Value.absent(),
            Value<String> bookSourceName = const Value.absent(),
            Value<String?> bookSourceGroup = const Value.absent(),
            Value<int> bookSourceType = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<bool> enabledExplore = const Value.absent(),
            Value<bool?> enabledCookieJar = const Value.absent(),
            Value<int> weight = const Value.absent(),
            Value<int> customOrder = const Value.absent(),
            Value<int> respondTime = const Value.absent(),
            Value<String?> header = const Value.absent(),
            Value<String?> loginUrl = const Value.absent(),
            Value<String?> bookSourceComment = const Value.absent(),
            Value<int> lastUpdateTime = const Value.absent(),
            Value<String?> rawJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SourceRecordsCompanion(
            bookSourceUrl: bookSourceUrl,
            bookSourceName: bookSourceName,
            bookSourceGroup: bookSourceGroup,
            bookSourceType: bookSourceType,
            enabled: enabled,
            enabledExplore: enabledExplore,
            enabledCookieJar: enabledCookieJar,
            weight: weight,
            customOrder: customOrder,
            respondTime: respondTime,
            header: header,
            loginUrl: loginUrl,
            bookSourceComment: bookSourceComment,
            lastUpdateTime: lastUpdateTime,
            rawJson: rawJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String bookSourceUrl,
            Value<String> bookSourceName = const Value.absent(),
            Value<String?> bookSourceGroup = const Value.absent(),
            Value<int> bookSourceType = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<bool> enabledExplore = const Value.absent(),
            Value<bool?> enabledCookieJar = const Value.absent(),
            Value<int> weight = const Value.absent(),
            Value<int> customOrder = const Value.absent(),
            Value<int> respondTime = const Value.absent(),
            Value<String?> header = const Value.absent(),
            Value<String?> loginUrl = const Value.absent(),
            Value<String?> bookSourceComment = const Value.absent(),
            Value<int> lastUpdateTime = const Value.absent(),
            Value<String?> rawJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SourceRecordsCompanion.insert(
            bookSourceUrl: bookSourceUrl,
            bookSourceName: bookSourceName,
            bookSourceGroup: bookSourceGroup,
            bookSourceType: bookSourceType,
            enabled: enabled,
            enabledExplore: enabledExplore,
            enabledCookieJar: enabledCookieJar,
            weight: weight,
            customOrder: customOrder,
            respondTime: respondTime,
            header: header,
            loginUrl: loginUrl,
            bookSourceComment: bookSourceComment,
            lastUpdateTime: lastUpdateTime,
            rawJson: rawJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SourceRecordsTableProcessedTableManager = ProcessedTableManager<
    _$SourceDriftDatabase,
    $SourceRecordsTable,
    SourceRecord,
    $$SourceRecordsTableFilterComposer,
    $$SourceRecordsTableOrderingComposer,
    $$SourceRecordsTableAnnotationComposer,
    $$SourceRecordsTableCreateCompanionBuilder,
    $$SourceRecordsTableUpdateCompanionBuilder,
    (
      SourceRecord,
      BaseReferences<_$SourceDriftDatabase, $SourceRecordsTable, SourceRecord>
    ),
    SourceRecord,
    PrefetchHooks Function()>;

class $SourceDriftDatabaseManager {
  final _$SourceDriftDatabase _db;
  $SourceDriftDatabaseManager(this._db);
  $$SourceRecordsTableTableManager get sourceRecords =>
      $$SourceRecordsTableTableManager(_db, _db.sourceRecords);
}
