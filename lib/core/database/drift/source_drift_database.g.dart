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

class $BookRecordsTable extends BookRecords
    with TableInfo<$BookRecordsTable, BookRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
      'intro', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceUrlMeta =
      const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
      'source_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _latestChapterMeta =
      const VerificationMeta('latestChapter');
  @override
  late final GeneratedColumn<String> latestChapter = GeneratedColumn<String>(
      'latest_chapter', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _totalChaptersMeta =
      const VerificationMeta('totalChapters');
  @override
  late final GeneratedColumn<int> totalChapters = GeneratedColumn<int>(
      'total_chapters', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currentChapterMeta =
      const VerificationMeta('currentChapter');
  @override
  late final GeneratedColumn<int> currentChapter = GeneratedColumn<int>(
      'current_chapter', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _readProgressMeta =
      const VerificationMeta('readProgress');
  @override
  late final GeneratedColumn<double> readProgress = GeneratedColumn<double>(
      'read_progress', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _lastReadTimeMeta =
      const VerificationMeta('lastReadTime');
  @override
  late final GeneratedColumn<int> lastReadTime = GeneratedColumn<int>(
      'last_read_time', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _addedTimeMeta =
      const VerificationMeta('addedTime');
  @override
  late final GeneratedColumn<int> addedTime = GeneratedColumn<int>(
      'added_time', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isLocalMeta =
      const VerificationMeta('isLocal');
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
      'is_local', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_local" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
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
        id,
        title,
        author,
        coverUrl,
        intro,
        sourceId,
        sourceUrl,
        latestChapter,
        totalChapters,
        currentChapter,
        readProgress,
        lastReadTime,
        addedTime,
        isLocal,
        localPath,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_records';
  @override
  VerificationContext validateIntegrity(Insertable<BookRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    }
    if (data.containsKey('intro')) {
      context.handle(
          _introMeta, intro.isAcceptableOrUnknown(data['intro']!, _introMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(_sourceUrlMeta,
          sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta));
    }
    if (data.containsKey('latest_chapter')) {
      context.handle(
          _latestChapterMeta,
          latestChapter.isAcceptableOrUnknown(
              data['latest_chapter']!, _latestChapterMeta));
    }
    if (data.containsKey('total_chapters')) {
      context.handle(
          _totalChaptersMeta,
          totalChapters.isAcceptableOrUnknown(
              data['total_chapters']!, _totalChaptersMeta));
    }
    if (data.containsKey('current_chapter')) {
      context.handle(
          _currentChapterMeta,
          currentChapter.isAcceptableOrUnknown(
              data['current_chapter']!, _currentChapterMeta));
    }
    if (data.containsKey('read_progress')) {
      context.handle(
          _readProgressMeta,
          readProgress.isAcceptableOrUnknown(
              data['read_progress']!, _readProgressMeta));
    }
    if (data.containsKey('last_read_time')) {
      context.handle(
          _lastReadTimeMeta,
          lastReadTime.isAcceptableOrUnknown(
              data['last_read_time']!, _lastReadTimeMeta));
    }
    if (data.containsKey('added_time')) {
      context.handle(_addedTimeMeta,
          addedTime.isAcceptableOrUnknown(data['added_time']!, _addedTimeMeta));
    }
    if (data.containsKey('is_local')) {
      context.handle(_isLocalMeta,
          isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta));
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      intro: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}intro']),
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id']),
      sourceUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_url']),
      latestChapter: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}latest_chapter']),
      totalChapters: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_chapters'])!,
      currentChapter: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_chapter'])!,
      readProgress: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}read_progress'])!,
      lastReadTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_read_time']),
      addedTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}added_time']),
      isLocal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_local'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BookRecordsTable createAlias(String alias) {
    return $BookRecordsTable(attachedDatabase, alias);
  }
}

class BookRecord extends DataClass implements Insertable<BookRecord> {
  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? intro;
  final String? sourceId;
  final String? sourceUrl;
  final String? latestChapter;
  final int totalChapters;
  final int currentChapter;
  final double readProgress;
  final int? lastReadTime;
  final int? addedTime;
  final bool isLocal;
  final String? localPath;
  final int updatedAt;
  const BookRecord(
      {required this.id,
      required this.title,
      required this.author,
      this.coverUrl,
      this.intro,
      this.sourceId,
      this.sourceUrl,
      this.latestChapter,
      required this.totalChapters,
      required this.currentChapter,
      required this.readProgress,
      this.lastReadTime,
      this.addedTime,
      required this.isLocal,
      this.localPath,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || intro != null) {
      map['intro'] = Variable<String>(intro);
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || latestChapter != null) {
      map['latest_chapter'] = Variable<String>(latestChapter);
    }
    map['total_chapters'] = Variable<int>(totalChapters);
    map['current_chapter'] = Variable<int>(currentChapter);
    map['read_progress'] = Variable<double>(readProgress);
    if (!nullToAbsent || lastReadTime != null) {
      map['last_read_time'] = Variable<int>(lastReadTime);
    }
    if (!nullToAbsent || addedTime != null) {
      map['added_time'] = Variable<int>(addedTime);
    }
    map['is_local'] = Variable<bool>(isLocal);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  BookRecordsCompanion toCompanion(bool nullToAbsent) {
    return BookRecordsCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      intro:
          intro == null && nullToAbsent ? const Value.absent() : Value(intro),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      latestChapter: latestChapter == null && nullToAbsent
          ? const Value.absent()
          : Value(latestChapter),
      totalChapters: Value(totalChapters),
      currentChapter: Value(currentChapter),
      readProgress: Value(readProgress),
      lastReadTime: lastReadTime == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadTime),
      addedTime: addedTime == null && nullToAbsent
          ? const Value.absent()
          : Value(addedTime),
      isLocal: Value(isLocal),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookRecord(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      intro: serializer.fromJson<String?>(json['intro']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      latestChapter: serializer.fromJson<String?>(json['latestChapter']),
      totalChapters: serializer.fromJson<int>(json['totalChapters']),
      currentChapter: serializer.fromJson<int>(json['currentChapter']),
      readProgress: serializer.fromJson<double>(json['readProgress']),
      lastReadTime: serializer.fromJson<int?>(json['lastReadTime']),
      addedTime: serializer.fromJson<int?>(json['addedTime']),
      isLocal: serializer.fromJson<bool>(json['isLocal']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'intro': serializer.toJson<String?>(intro),
      'sourceId': serializer.toJson<String?>(sourceId),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'latestChapter': serializer.toJson<String?>(latestChapter),
      'totalChapters': serializer.toJson<int>(totalChapters),
      'currentChapter': serializer.toJson<int>(currentChapter),
      'readProgress': serializer.toJson<double>(readProgress),
      'lastReadTime': serializer.toJson<int?>(lastReadTime),
      'addedTime': serializer.toJson<int?>(addedTime),
      'isLocal': serializer.toJson<bool>(isLocal),
      'localPath': serializer.toJson<String?>(localPath),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  BookRecord copyWith(
          {String? id,
          String? title,
          String? author,
          Value<String?> coverUrl = const Value.absent(),
          Value<String?> intro = const Value.absent(),
          Value<String?> sourceId = const Value.absent(),
          Value<String?> sourceUrl = const Value.absent(),
          Value<String?> latestChapter = const Value.absent(),
          int? totalChapters,
          int? currentChapter,
          double? readProgress,
          Value<int?> lastReadTime = const Value.absent(),
          Value<int?> addedTime = const Value.absent(),
          bool? isLocal,
          Value<String?> localPath = const Value.absent(),
          int? updatedAt}) =>
      BookRecord(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        intro: intro.present ? intro.value : this.intro,
        sourceId: sourceId.present ? sourceId.value : this.sourceId,
        sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
        latestChapter:
            latestChapter.present ? latestChapter.value : this.latestChapter,
        totalChapters: totalChapters ?? this.totalChapters,
        currentChapter: currentChapter ?? this.currentChapter,
        readProgress: readProgress ?? this.readProgress,
        lastReadTime:
            lastReadTime.present ? lastReadTime.value : this.lastReadTime,
        addedTime: addedTime.present ? addedTime.value : this.addedTime,
        isLocal: isLocal ?? this.isLocal,
        localPath: localPath.present ? localPath.value : this.localPath,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  BookRecord copyWithCompanion(BookRecordsCompanion data) {
    return BookRecord(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      intro: data.intro.present ? data.intro.value : this.intro,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      latestChapter: data.latestChapter.present
          ? data.latestChapter.value
          : this.latestChapter,
      totalChapters: data.totalChapters.present
          ? data.totalChapters.value
          : this.totalChapters,
      currentChapter: data.currentChapter.present
          ? data.currentChapter.value
          : this.currentChapter,
      readProgress: data.readProgress.present
          ? data.readProgress.value
          : this.readProgress,
      lastReadTime: data.lastReadTime.present
          ? data.lastReadTime.value
          : this.lastReadTime,
      addedTime: data.addedTime.present ? data.addedTime.value : this.addedTime,
      isLocal: data.isLocal.present ? data.isLocal.value : this.isLocal,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookRecord(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('intro: $intro, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('latestChapter: $latestChapter, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('currentChapter: $currentChapter, ')
          ..write('readProgress: $readProgress, ')
          ..write('lastReadTime: $lastReadTime, ')
          ..write('addedTime: $addedTime, ')
          ..write('isLocal: $isLocal, ')
          ..write('localPath: $localPath, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      author,
      coverUrl,
      intro,
      sourceId,
      sourceUrl,
      latestChapter,
      totalChapters,
      currentChapter,
      readProgress,
      lastReadTime,
      addedTime,
      isLocal,
      localPath,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookRecord &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.coverUrl == this.coverUrl &&
          other.intro == this.intro &&
          other.sourceId == this.sourceId &&
          other.sourceUrl == this.sourceUrl &&
          other.latestChapter == this.latestChapter &&
          other.totalChapters == this.totalChapters &&
          other.currentChapter == this.currentChapter &&
          other.readProgress == this.readProgress &&
          other.lastReadTime == this.lastReadTime &&
          other.addedTime == this.addedTime &&
          other.isLocal == this.isLocal &&
          other.localPath == this.localPath &&
          other.updatedAt == this.updatedAt);
}

class BookRecordsCompanion extends UpdateCompanion<BookRecord> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> author;
  final Value<String?> coverUrl;
  final Value<String?> intro;
  final Value<String?> sourceId;
  final Value<String?> sourceUrl;
  final Value<String?> latestChapter;
  final Value<int> totalChapters;
  final Value<int> currentChapter;
  final Value<double> readProgress;
  final Value<int?> lastReadTime;
  final Value<int?> addedTime;
  final Value<bool> isLocal;
  final Value<String?> localPath;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const BookRecordsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.intro = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.latestChapter = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.currentChapter = const Value.absent(),
    this.readProgress = const Value.absent(),
    this.lastReadTime = const Value.absent(),
    this.addedTime = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.localPath = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookRecordsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.intro = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.latestChapter = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.currentChapter = const Value.absent(),
    this.readProgress = const Value.absent(),
    this.lastReadTime = const Value.absent(),
    this.addedTime = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.localPath = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<BookRecord> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? coverUrl,
    Expression<String>? intro,
    Expression<String>? sourceId,
    Expression<String>? sourceUrl,
    Expression<String>? latestChapter,
    Expression<int>? totalChapters,
    Expression<int>? currentChapter,
    Expression<double>? readProgress,
    Expression<int>? lastReadTime,
    Expression<int>? addedTime,
    Expression<bool>? isLocal,
    Expression<String>? localPath,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (intro != null) 'intro': intro,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (latestChapter != null) 'latest_chapter': latestChapter,
      if (totalChapters != null) 'total_chapters': totalChapters,
      if (currentChapter != null) 'current_chapter': currentChapter,
      if (readProgress != null) 'read_progress': readProgress,
      if (lastReadTime != null) 'last_read_time': lastReadTime,
      if (addedTime != null) 'added_time': addedTime,
      if (isLocal != null) 'is_local': isLocal,
      if (localPath != null) 'local_path': localPath,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookRecordsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? author,
      Value<String?>? coverUrl,
      Value<String?>? intro,
      Value<String?>? sourceId,
      Value<String?>? sourceUrl,
      Value<String?>? latestChapter,
      Value<int>? totalChapters,
      Value<int>? currentChapter,
      Value<double>? readProgress,
      Value<int?>? lastReadTime,
      Value<int?>? addedTime,
      Value<bool>? isLocal,
      Value<String?>? localPath,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return BookRecordsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      intro: intro ?? this.intro,
      sourceId: sourceId ?? this.sourceId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      latestChapter: latestChapter ?? this.latestChapter,
      totalChapters: totalChapters ?? this.totalChapters,
      currentChapter: currentChapter ?? this.currentChapter,
      readProgress: readProgress ?? this.readProgress,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      addedTime: addedTime ?? this.addedTime,
      isLocal: isLocal ?? this.isLocal,
      localPath: localPath ?? this.localPath,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (latestChapter.present) {
      map['latest_chapter'] = Variable<String>(latestChapter.value);
    }
    if (totalChapters.present) {
      map['total_chapters'] = Variable<int>(totalChapters.value);
    }
    if (currentChapter.present) {
      map['current_chapter'] = Variable<int>(currentChapter.value);
    }
    if (readProgress.present) {
      map['read_progress'] = Variable<double>(readProgress.value);
    }
    if (lastReadTime.present) {
      map['last_read_time'] = Variable<int>(lastReadTime.value);
    }
    if (addedTime.present) {
      map['added_time'] = Variable<int>(addedTime.value);
    }
    if (isLocal.present) {
      map['is_local'] = Variable<bool>(isLocal.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
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
    return (StringBuffer('BookRecordsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('intro: $intro, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('latestChapter: $latestChapter, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('currentChapter: $currentChapter, ')
          ..write('readProgress: $readProgress, ')
          ..write('lastReadTime: $lastReadTime, ')
          ..write('addedTime: $addedTime, ')
          ..write('isLocal: $isLocal, ')
          ..write('localPath: $localPath, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChapterRecordsTable extends ChapterRecords
    with TableInfo<$ChapterRecordsTable, ChapterRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _chapterIndexMeta =
      const VerificationMeta('chapterIndex');
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
      'chapter_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isDownloadedMeta =
      const VerificationMeta('isDownloaded');
  @override
  late final GeneratedColumn<bool> isDownloaded = GeneratedColumn<bool>(
      'is_downloaded', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_downloaded" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, true,
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
  List<GeneratedColumn> get $columns =>
      [id, bookId, title, url, chapterIndex, isDownloaded, content, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_records';
  @override
  VerificationContext validateIntegrity(Insertable<ChapterRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
          _chapterIndexMeta,
          chapterIndex.isAcceptableOrUnknown(
              data['chapter_index']!, _chapterIndexMeta));
    }
    if (data.containsKey('is_downloaded')) {
      context.handle(
          _isDownloadedMeta,
          isDownloaded.isAcceptableOrUnknown(
              data['is_downloaded']!, _isDownloadedMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChapterRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url']),
      chapterIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_index'])!,
      isDownloaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_downloaded'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ChapterRecordsTable createAlias(String alias) {
    return $ChapterRecordsTable(attachedDatabase, alias);
  }
}

class ChapterRecord extends DataClass implements Insertable<ChapterRecord> {
  final String id;
  final String bookId;
  final String title;
  final String? url;
  final int chapterIndex;
  final bool isDownloaded;
  final String? content;
  final int updatedAt;
  const ChapterRecord(
      {required this.id,
      required this.bookId,
      required this.title,
      this.url,
      required this.chapterIndex,
      required this.isDownloaded,
      this.content,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['is_downloaded'] = Variable<bool>(isDownloaded);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ChapterRecordsCompanion toCompanion(bool nullToAbsent) {
    return ChapterRecordsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      title: Value(title),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      chapterIndex: Value(chapterIndex),
      isDownloaded: Value(isDownloaded),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChapterRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterRecord(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      title: serializer.fromJson<String>(json['title']),
      url: serializer.fromJson<String?>(json['url']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      isDownloaded: serializer.fromJson<bool>(json['isDownloaded']),
      content: serializer.fromJson<String?>(json['content']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'title': serializer.toJson<String>(title),
      'url': serializer.toJson<String?>(url),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'isDownloaded': serializer.toJson<bool>(isDownloaded),
      'content': serializer.toJson<String?>(content),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ChapterRecord copyWith(
          {String? id,
          String? bookId,
          String? title,
          Value<String?> url = const Value.absent(),
          int? chapterIndex,
          bool? isDownloaded,
          Value<String?> content = const Value.absent(),
          int? updatedAt}) =>
      ChapterRecord(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        title: title ?? this.title,
        url: url.present ? url.value : this.url,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        content: content.present ? content.value : this.content,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ChapterRecord copyWithCompanion(ChapterRecordsCompanion data) {
    return ChapterRecord(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      title: data.title.present ? data.title.value : this.title,
      url: data.url.present ? data.url.value : this.url,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      isDownloaded: data.isDownloaded.present
          ? data.isDownloaded.value
          : this.isDownloaded,
      content: data.content.present ? data.content.value : this.content,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterRecord(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('content: $content, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, bookId, title, url, chapterIndex, isDownloaded, content, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterRecord &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.title == this.title &&
          other.url == this.url &&
          other.chapterIndex == this.chapterIndex &&
          other.isDownloaded == this.isDownloaded &&
          other.content == this.content &&
          other.updatedAt == this.updatedAt);
}

class ChapterRecordsCompanion extends UpdateCompanion<ChapterRecord> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> title;
  final Value<String?> url;
  final Value<int> chapterIndex;
  final Value<bool> isDownloaded;
  final Value<String?> content;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ChapterRecordsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.title = const Value.absent(),
    this.url = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.content = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChapterRecordsCompanion.insert({
    required String id,
    required String bookId,
    this.title = const Value.absent(),
    this.url = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.content = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        bookId = Value(bookId);
  static Insertable<ChapterRecord> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? title,
    Expression<String>? url,
    Expression<int>? chapterIndex,
    Expression<bool>? isDownloaded,
    Expression<String>? content,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (title != null) 'title': title,
      if (url != null) 'url': url,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (isDownloaded != null) 'is_downloaded': isDownloaded,
      if (content != null) 'content': content,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChapterRecordsCompanion copyWith(
      {Value<String>? id,
      Value<String>? bookId,
      Value<String>? title,
      Value<String?>? url,
      Value<int>? chapterIndex,
      Value<bool>? isDownloaded,
      Value<String?>? content,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return ChapterRecordsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      url: url ?? this.url,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (isDownloaded.present) {
      map['is_downloaded'] = Variable<bool>(isDownloaded.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
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
    return (StringBuffer('ChapterRecordsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('content: $content, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReplaceRuleRecordsTable extends ReplaceRuleRecords
    with TableInfo<$ReplaceRuleRecordsTable, ReplaceRuleRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReplaceRuleRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'group_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _patternMeta =
      const VerificationMeta('pattern');
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
      'pattern', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _replacementMeta =
      const VerificationMeta('replacement');
  @override
  late final GeneratedColumn<String> replacement = GeneratedColumn<String>(
      'replacement', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
      'scope', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scopeTitleMeta =
      const VerificationMeta('scopeTitle');
  @override
  late final GeneratedColumn<bool> scopeTitle = GeneratedColumn<bool>(
      'scope_title', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("scope_title" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _scopeContentMeta =
      const VerificationMeta('scopeContent');
  @override
  late final GeneratedColumn<bool> scopeContent = GeneratedColumn<bool>(
      'scope_content', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("scope_content" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _excludeScopeMeta =
      const VerificationMeta('excludeScope');
  @override
  late final GeneratedColumn<String> excludeScope = GeneratedColumn<String>(
      'exclude_scope', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isEnabledMeta =
      const VerificationMeta('isEnabled');
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
      'is_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _isRegexMeta =
      const VerificationMeta('isRegex');
  @override
  late final GeneratedColumn<bool> isRegex = GeneratedColumn<bool>(
      'is_regex', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_regex" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _timeoutMillisecondMeta =
      const VerificationMeta('timeoutMillisecond');
  @override
  late final GeneratedColumn<int> timeoutMillisecond = GeneratedColumn<int>(
      'timeout_millisecond', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(3000));
  static const VerificationMeta _orderValueMeta =
      const VerificationMeta('orderValue');
  @override
  late final GeneratedColumn<int> orderValue = GeneratedColumn<int>(
      'order_value', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(-2147483648));
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
        id,
        name,
        groupName,
        pattern,
        replacement,
        scope,
        scopeTitle,
        scopeContent,
        excludeScope,
        isEnabled,
        isRegex,
        timeoutMillisecond,
        orderValue,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'replace_rule_records';
  @override
  VerificationContext validateIntegrity(Insertable<ReplaceRuleRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('group_name')) {
      context.handle(_groupNameMeta,
          groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta));
    }
    if (data.containsKey('pattern')) {
      context.handle(_patternMeta,
          pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta));
    }
    if (data.containsKey('replacement')) {
      context.handle(
          _replacementMeta,
          replacement.isAcceptableOrUnknown(
              data['replacement']!, _replacementMeta));
    }
    if (data.containsKey('scope')) {
      context.handle(
          _scopeMeta, scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta));
    }
    if (data.containsKey('scope_title')) {
      context.handle(
          _scopeTitleMeta,
          scopeTitle.isAcceptableOrUnknown(
              data['scope_title']!, _scopeTitleMeta));
    }
    if (data.containsKey('scope_content')) {
      context.handle(
          _scopeContentMeta,
          scopeContent.isAcceptableOrUnknown(
              data['scope_content']!, _scopeContentMeta));
    }
    if (data.containsKey('exclude_scope')) {
      context.handle(
          _excludeScopeMeta,
          excludeScope.isAcceptableOrUnknown(
              data['exclude_scope']!, _excludeScopeMeta));
    }
    if (data.containsKey('is_enabled')) {
      context.handle(_isEnabledMeta,
          isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta));
    }
    if (data.containsKey('is_regex')) {
      context.handle(_isRegexMeta,
          isRegex.isAcceptableOrUnknown(data['is_regex']!, _isRegexMeta));
    }
    if (data.containsKey('timeout_millisecond')) {
      context.handle(
          _timeoutMillisecondMeta,
          timeoutMillisecond.isAcceptableOrUnknown(
              data['timeout_millisecond']!, _timeoutMillisecondMeta));
    }
    if (data.containsKey('order_value')) {
      context.handle(
          _orderValueMeta,
          orderValue.isAcceptableOrUnknown(
              data['order_value']!, _orderValueMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReplaceRuleRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReplaceRuleRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      groupName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_name']),
      pattern: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pattern'])!,
      replacement: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}replacement'])!,
      scope: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope']),
      scopeTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}scope_title'])!,
      scopeContent: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}scope_content'])!,
      excludeScope: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exclude_scope']),
      isEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_enabled'])!,
      isRegex: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_regex'])!,
      timeoutMillisecond: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}timeout_millisecond'])!,
      orderValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ReplaceRuleRecordsTable createAlias(String alias) {
    return $ReplaceRuleRecordsTable(attachedDatabase, alias);
  }
}

class ReplaceRuleRecord extends DataClass
    implements Insertable<ReplaceRuleRecord> {
  final int id;
  final String name;
  final String? groupName;
  final String pattern;
  final String replacement;
  final String? scope;
  final bool scopeTitle;
  final bool scopeContent;
  final String? excludeScope;
  final bool isEnabled;
  final bool isRegex;
  final int timeoutMillisecond;
  final int orderValue;
  final int updatedAt;
  const ReplaceRuleRecord(
      {required this.id,
      required this.name,
      this.groupName,
      required this.pattern,
      required this.replacement,
      this.scope,
      required this.scopeTitle,
      required this.scopeContent,
      this.excludeScope,
      required this.isEnabled,
      required this.isRegex,
      required this.timeoutMillisecond,
      required this.orderValue,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    map['pattern'] = Variable<String>(pattern);
    map['replacement'] = Variable<String>(replacement);
    if (!nullToAbsent || scope != null) {
      map['scope'] = Variable<String>(scope);
    }
    map['scope_title'] = Variable<bool>(scopeTitle);
    map['scope_content'] = Variable<bool>(scopeContent);
    if (!nullToAbsent || excludeScope != null) {
      map['exclude_scope'] = Variable<String>(excludeScope);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['is_regex'] = Variable<bool>(isRegex);
    map['timeout_millisecond'] = Variable<int>(timeoutMillisecond);
    map['order_value'] = Variable<int>(orderValue);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ReplaceRuleRecordsCompanion toCompanion(bool nullToAbsent) {
    return ReplaceRuleRecordsCompanion(
      id: Value(id),
      name: Value(name),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      pattern: Value(pattern),
      replacement: Value(replacement),
      scope:
          scope == null && nullToAbsent ? const Value.absent() : Value(scope),
      scopeTitle: Value(scopeTitle),
      scopeContent: Value(scopeContent),
      excludeScope: excludeScope == null && nullToAbsent
          ? const Value.absent()
          : Value(excludeScope),
      isEnabled: Value(isEnabled),
      isRegex: Value(isRegex),
      timeoutMillisecond: Value(timeoutMillisecond),
      orderValue: Value(orderValue),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReplaceRuleRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReplaceRuleRecord(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      pattern: serializer.fromJson<String>(json['pattern']),
      replacement: serializer.fromJson<String>(json['replacement']),
      scope: serializer.fromJson<String?>(json['scope']),
      scopeTitle: serializer.fromJson<bool>(json['scopeTitle']),
      scopeContent: serializer.fromJson<bool>(json['scopeContent']),
      excludeScope: serializer.fromJson<String?>(json['excludeScope']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      isRegex: serializer.fromJson<bool>(json['isRegex']),
      timeoutMillisecond: serializer.fromJson<int>(json['timeoutMillisecond']),
      orderValue: serializer.fromJson<int>(json['orderValue']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'groupName': serializer.toJson<String?>(groupName),
      'pattern': serializer.toJson<String>(pattern),
      'replacement': serializer.toJson<String>(replacement),
      'scope': serializer.toJson<String?>(scope),
      'scopeTitle': serializer.toJson<bool>(scopeTitle),
      'scopeContent': serializer.toJson<bool>(scopeContent),
      'excludeScope': serializer.toJson<String?>(excludeScope),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'isRegex': serializer.toJson<bool>(isRegex),
      'timeoutMillisecond': serializer.toJson<int>(timeoutMillisecond),
      'orderValue': serializer.toJson<int>(orderValue),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ReplaceRuleRecord copyWith(
          {int? id,
          String? name,
          Value<String?> groupName = const Value.absent(),
          String? pattern,
          String? replacement,
          Value<String?> scope = const Value.absent(),
          bool? scopeTitle,
          bool? scopeContent,
          Value<String?> excludeScope = const Value.absent(),
          bool? isEnabled,
          bool? isRegex,
          int? timeoutMillisecond,
          int? orderValue,
          int? updatedAt}) =>
      ReplaceRuleRecord(
        id: id ?? this.id,
        name: name ?? this.name,
        groupName: groupName.present ? groupName.value : this.groupName,
        pattern: pattern ?? this.pattern,
        replacement: replacement ?? this.replacement,
        scope: scope.present ? scope.value : this.scope,
        scopeTitle: scopeTitle ?? this.scopeTitle,
        scopeContent: scopeContent ?? this.scopeContent,
        excludeScope:
            excludeScope.present ? excludeScope.value : this.excludeScope,
        isEnabled: isEnabled ?? this.isEnabled,
        isRegex: isRegex ?? this.isRegex,
        timeoutMillisecond: timeoutMillisecond ?? this.timeoutMillisecond,
        orderValue: orderValue ?? this.orderValue,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ReplaceRuleRecord copyWithCompanion(ReplaceRuleRecordsCompanion data) {
    return ReplaceRuleRecord(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      replacement:
          data.replacement.present ? data.replacement.value : this.replacement,
      scope: data.scope.present ? data.scope.value : this.scope,
      scopeTitle:
          data.scopeTitle.present ? data.scopeTitle.value : this.scopeTitle,
      scopeContent: data.scopeContent.present
          ? data.scopeContent.value
          : this.scopeContent,
      excludeScope: data.excludeScope.present
          ? data.excludeScope.value
          : this.excludeScope,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      isRegex: data.isRegex.present ? data.isRegex.value : this.isRegex,
      timeoutMillisecond: data.timeoutMillisecond.present
          ? data.timeoutMillisecond.value
          : this.timeoutMillisecond,
      orderValue:
          data.orderValue.present ? data.orderValue.value : this.orderValue,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReplaceRuleRecord(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupName: $groupName, ')
          ..write('pattern: $pattern, ')
          ..write('replacement: $replacement, ')
          ..write('scope: $scope, ')
          ..write('scopeTitle: $scopeTitle, ')
          ..write('scopeContent: $scopeContent, ')
          ..write('excludeScope: $excludeScope, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isRegex: $isRegex, ')
          ..write('timeoutMillisecond: $timeoutMillisecond, ')
          ..write('orderValue: $orderValue, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      groupName,
      pattern,
      replacement,
      scope,
      scopeTitle,
      scopeContent,
      excludeScope,
      isEnabled,
      isRegex,
      timeoutMillisecond,
      orderValue,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReplaceRuleRecord &&
          other.id == this.id &&
          other.name == this.name &&
          other.groupName == this.groupName &&
          other.pattern == this.pattern &&
          other.replacement == this.replacement &&
          other.scope == this.scope &&
          other.scopeTitle == this.scopeTitle &&
          other.scopeContent == this.scopeContent &&
          other.excludeScope == this.excludeScope &&
          other.isEnabled == this.isEnabled &&
          other.isRegex == this.isRegex &&
          other.timeoutMillisecond == this.timeoutMillisecond &&
          other.orderValue == this.orderValue &&
          other.updatedAt == this.updatedAt);
}

class ReplaceRuleRecordsCompanion extends UpdateCompanion<ReplaceRuleRecord> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> groupName;
  final Value<String> pattern;
  final Value<String> replacement;
  final Value<String?> scope;
  final Value<bool> scopeTitle;
  final Value<bool> scopeContent;
  final Value<String?> excludeScope;
  final Value<bool> isEnabled;
  final Value<bool> isRegex;
  final Value<int> timeoutMillisecond;
  final Value<int> orderValue;
  final Value<int> updatedAt;
  const ReplaceRuleRecordsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.groupName = const Value.absent(),
    this.pattern = const Value.absent(),
    this.replacement = const Value.absent(),
    this.scope = const Value.absent(),
    this.scopeTitle = const Value.absent(),
    this.scopeContent = const Value.absent(),
    this.excludeScope = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isRegex = const Value.absent(),
    this.timeoutMillisecond = const Value.absent(),
    this.orderValue = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ReplaceRuleRecordsCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.groupName = const Value.absent(),
    this.pattern = const Value.absent(),
    this.replacement = const Value.absent(),
    this.scope = const Value.absent(),
    this.scopeTitle = const Value.absent(),
    this.scopeContent = const Value.absent(),
    this.excludeScope = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isRegex = const Value.absent(),
    this.timeoutMillisecond = const Value.absent(),
    this.orderValue = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<ReplaceRuleRecord> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? groupName,
    Expression<String>? pattern,
    Expression<String>? replacement,
    Expression<String>? scope,
    Expression<bool>? scopeTitle,
    Expression<bool>? scopeContent,
    Expression<String>? excludeScope,
    Expression<bool>? isEnabled,
    Expression<bool>? isRegex,
    Expression<int>? timeoutMillisecond,
    Expression<int>? orderValue,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (groupName != null) 'group_name': groupName,
      if (pattern != null) 'pattern': pattern,
      if (replacement != null) 'replacement': replacement,
      if (scope != null) 'scope': scope,
      if (scopeTitle != null) 'scope_title': scopeTitle,
      if (scopeContent != null) 'scope_content': scopeContent,
      if (excludeScope != null) 'exclude_scope': excludeScope,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (isRegex != null) 'is_regex': isRegex,
      if (timeoutMillisecond != null) 'timeout_millisecond': timeoutMillisecond,
      if (orderValue != null) 'order_value': orderValue,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ReplaceRuleRecordsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? groupName,
      Value<String>? pattern,
      Value<String>? replacement,
      Value<String?>? scope,
      Value<bool>? scopeTitle,
      Value<bool>? scopeContent,
      Value<String?>? excludeScope,
      Value<bool>? isEnabled,
      Value<bool>? isRegex,
      Value<int>? timeoutMillisecond,
      Value<int>? orderValue,
      Value<int>? updatedAt}) {
    return ReplaceRuleRecordsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      groupName: groupName ?? this.groupName,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      scope: scope ?? this.scope,
      scopeTitle: scopeTitle ?? this.scopeTitle,
      scopeContent: scopeContent ?? this.scopeContent,
      excludeScope: excludeScope ?? this.excludeScope,
      isEnabled: isEnabled ?? this.isEnabled,
      isRegex: isRegex ?? this.isRegex,
      timeoutMillisecond: timeoutMillisecond ?? this.timeoutMillisecond,
      orderValue: orderValue ?? this.orderValue,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (replacement.present) {
      map['replacement'] = Variable<String>(replacement.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (scopeTitle.present) {
      map['scope_title'] = Variable<bool>(scopeTitle.value);
    }
    if (scopeContent.present) {
      map['scope_content'] = Variable<bool>(scopeContent.value);
    }
    if (excludeScope.present) {
      map['exclude_scope'] = Variable<String>(excludeScope.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (isRegex.present) {
      map['is_regex'] = Variable<bool>(isRegex.value);
    }
    if (timeoutMillisecond.present) {
      map['timeout_millisecond'] = Variable<int>(timeoutMillisecond.value);
    }
    if (orderValue.present) {
      map['order_value'] = Variable<int>(orderValue.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReplaceRuleRecordsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupName: $groupName, ')
          ..write('pattern: $pattern, ')
          ..write('replacement: $replacement, ')
          ..write('scope: $scope, ')
          ..write('scopeTitle: $scopeTitle, ')
          ..write('scopeContent: $scopeContent, ')
          ..write('excludeScope: $excludeScope, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isRegex: $isRegex, ')
          ..write('timeoutMillisecond: $timeoutMillisecond, ')
          ..write('orderValue: $orderValue, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AppKeyValueRecordsTable extends AppKeyValueRecords
    with TableInfo<$AppKeyValueRecordsTable, AppKeyValueRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppKeyValueRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, true,
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
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_key_value_records';
  @override
  VerificationContext validateIntegrity(Insertable<AppKeyValueRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppKeyValueRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppKeyValueRecord(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AppKeyValueRecordsTable createAlias(String alias) {
    return $AppKeyValueRecordsTable(attachedDatabase, alias);
  }
}

class AppKeyValueRecord extends DataClass
    implements Insertable<AppKeyValueRecord> {
  final String key;
  final String? value;
  final int updatedAt;
  const AppKeyValueRecord(
      {required this.key, this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AppKeyValueRecordsCompanion toCompanion(bool nullToAbsent) {
    return AppKeyValueRecordsCompanion(
      key: Value(key),
      value:
          value == null && nullToAbsent ? const Value.absent() : Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppKeyValueRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppKeyValueRecord(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AppKeyValueRecord copyWith(
          {String? key,
          Value<String?> value = const Value.absent(),
          int? updatedAt}) =>
      AppKeyValueRecord(
        key: key ?? this.key,
        value: value.present ? value.value : this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppKeyValueRecord copyWithCompanion(AppKeyValueRecordsCompanion data) {
    return AppKeyValueRecord(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppKeyValueRecord(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppKeyValueRecord &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppKeyValueRecordsCompanion extends UpdateCompanion<AppKeyValueRecord> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AppKeyValueRecordsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppKeyValueRecordsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<AppKeyValueRecord> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppKeyValueRecordsCompanion copyWith(
      {Value<String>? key,
      Value<String?>? value,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return AppKeyValueRecordsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
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
    return (StringBuffer('AppKeyValueRecordsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarkRecordsTable extends BookmarkRecords
    with TableInfo<$BookmarkRecordsTable, BookmarkRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarkRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookNameMeta =
      const VerificationMeta('bookName');
  @override
  late final GeneratedColumn<String> bookName = GeneratedColumn<String>(
      'book_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _bookAuthorMeta =
      const VerificationMeta('bookAuthor');
  @override
  late final GeneratedColumn<String> bookAuthor = GeneratedColumn<String>(
      'book_author', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _chapterIndexMeta =
      const VerificationMeta('chapterIndex');
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
      'chapter_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _chapterTitleMeta =
      const VerificationMeta('chapterTitle');
  @override
  late final GeneratedColumn<String> chapterTitle = GeneratedColumn<String>(
      'chapter_title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _chapterPosMeta =
      const VerificationMeta('chapterPos');
  @override
  late final GeneratedColumn<int> chapterPos = GeneratedColumn<int>(
      'chapter_pos', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdTimeMeta =
      const VerificationMeta('createdTime');
  @override
  late final GeneratedColumn<int> createdTime = GeneratedColumn<int>(
      'created_time', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        id,
        bookId,
        bookName,
        bookAuthor,
        chapterIndex,
        chapterTitle,
        chapterPos,
        content,
        createdTime,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmark_records';
  @override
  VerificationContext validateIntegrity(Insertable<BookmarkRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('book_name')) {
      context.handle(_bookNameMeta,
          bookName.isAcceptableOrUnknown(data['book_name']!, _bookNameMeta));
    }
    if (data.containsKey('book_author')) {
      context.handle(
          _bookAuthorMeta,
          bookAuthor.isAcceptableOrUnknown(
              data['book_author']!, _bookAuthorMeta));
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
          _chapterIndexMeta,
          chapterIndex.isAcceptableOrUnknown(
              data['chapter_index']!, _chapterIndexMeta));
    }
    if (data.containsKey('chapter_title')) {
      context.handle(
          _chapterTitleMeta,
          chapterTitle.isAcceptableOrUnknown(
              data['chapter_title']!, _chapterTitleMeta));
    }
    if (data.containsKey('chapter_pos')) {
      context.handle(
          _chapterPosMeta,
          chapterPos.isAcceptableOrUnknown(
              data['chapter_pos']!, _chapterPosMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    }
    if (data.containsKey('created_time')) {
      context.handle(
          _createdTimeMeta,
          createdTime.isAcceptableOrUnknown(
              data['created_time']!, _createdTimeMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookmarkRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      bookName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_name'])!,
      bookAuthor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_author'])!,
      chapterIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_index'])!,
      chapterTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapter_title'])!,
      chapterPos: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_pos'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      createdTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_time'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BookmarkRecordsTable createAlias(String alias) {
    return $BookmarkRecordsTable(attachedDatabase, alias);
  }
}

class BookmarkRecord extends DataClass implements Insertable<BookmarkRecord> {
  final String id;
  final String bookId;
  final String bookName;
  final String bookAuthor;
  final int chapterIndex;
  final String chapterTitle;
  final int chapterPos;
  final String content;
  final int createdTime;
  final int updatedAt;
  const BookmarkRecord(
      {required this.id,
      required this.bookId,
      required this.bookName,
      required this.bookAuthor,
      required this.chapterIndex,
      required this.chapterTitle,
      required this.chapterPos,
      required this.content,
      required this.createdTime,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['book_name'] = Variable<String>(bookName);
    map['book_author'] = Variable<String>(bookAuthor);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['chapter_title'] = Variable<String>(chapterTitle);
    map['chapter_pos'] = Variable<int>(chapterPos);
    map['content'] = Variable<String>(content);
    map['created_time'] = Variable<int>(createdTime);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  BookmarkRecordsCompanion toCompanion(bool nullToAbsent) {
    return BookmarkRecordsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      bookName: Value(bookName),
      bookAuthor: Value(bookAuthor),
      chapterIndex: Value(chapterIndex),
      chapterTitle: Value(chapterTitle),
      chapterPos: Value(chapterPos),
      content: Value(content),
      createdTime: Value(createdTime),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookmarkRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkRecord(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      bookName: serializer.fromJson<String>(json['bookName']),
      bookAuthor: serializer.fromJson<String>(json['bookAuthor']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      chapterTitle: serializer.fromJson<String>(json['chapterTitle']),
      chapterPos: serializer.fromJson<int>(json['chapterPos']),
      content: serializer.fromJson<String>(json['content']),
      createdTime: serializer.fromJson<int>(json['createdTime']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'bookName': serializer.toJson<String>(bookName),
      'bookAuthor': serializer.toJson<String>(bookAuthor),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'chapterTitle': serializer.toJson<String>(chapterTitle),
      'chapterPos': serializer.toJson<int>(chapterPos),
      'content': serializer.toJson<String>(content),
      'createdTime': serializer.toJson<int>(createdTime),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  BookmarkRecord copyWith(
          {String? id,
          String? bookId,
          String? bookName,
          String? bookAuthor,
          int? chapterIndex,
          String? chapterTitle,
          int? chapterPos,
          String? content,
          int? createdTime,
          int? updatedAt}) =>
      BookmarkRecord(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        bookName: bookName ?? this.bookName,
        bookAuthor: bookAuthor ?? this.bookAuthor,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        chapterTitle: chapterTitle ?? this.chapterTitle,
        chapterPos: chapterPos ?? this.chapterPos,
        content: content ?? this.content,
        createdTime: createdTime ?? this.createdTime,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  BookmarkRecord copyWithCompanion(BookmarkRecordsCompanion data) {
    return BookmarkRecord(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      bookName: data.bookName.present ? data.bookName.value : this.bookName,
      bookAuthor:
          data.bookAuthor.present ? data.bookAuthor.value : this.bookAuthor,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      chapterTitle: data.chapterTitle.present
          ? data.chapterTitle.value
          : this.chapterTitle,
      chapterPos:
          data.chapterPos.present ? data.chapterPos.value : this.chapterPos,
      content: data.content.present ? data.content.value : this.content,
      createdTime:
          data.createdTime.present ? data.createdTime.value : this.createdTime,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkRecord(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('bookName: $bookName, ')
          ..write('bookAuthor: $bookAuthor, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('chapterPos: $chapterPos, ')
          ..write('content: $content, ')
          ..write('createdTime: $createdTime, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, bookName, bookAuthor,
      chapterIndex, chapterTitle, chapterPos, content, createdTime, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkRecord &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.bookName == this.bookName &&
          other.bookAuthor == this.bookAuthor &&
          other.chapterIndex == this.chapterIndex &&
          other.chapterTitle == this.chapterTitle &&
          other.chapterPos == this.chapterPos &&
          other.content == this.content &&
          other.createdTime == this.createdTime &&
          other.updatedAt == this.updatedAt);
}

class BookmarkRecordsCompanion extends UpdateCompanion<BookmarkRecord> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> bookName;
  final Value<String> bookAuthor;
  final Value<int> chapterIndex;
  final Value<String> chapterTitle;
  final Value<int> chapterPos;
  final Value<String> content;
  final Value<int> createdTime;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const BookmarkRecordsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.bookName = const Value.absent(),
    this.bookAuthor = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.chapterPos = const Value.absent(),
    this.content = const Value.absent(),
    this.createdTime = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarkRecordsCompanion.insert({
    required String id,
    required String bookId,
    this.bookName = const Value.absent(),
    this.bookAuthor = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.chapterPos = const Value.absent(),
    this.content = const Value.absent(),
    this.createdTime = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        bookId = Value(bookId);
  static Insertable<BookmarkRecord> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? bookName,
    Expression<String>? bookAuthor,
    Expression<int>? chapterIndex,
    Expression<String>? chapterTitle,
    Expression<int>? chapterPos,
    Expression<String>? content,
    Expression<int>? createdTime,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (bookName != null) 'book_name': bookName,
      if (bookAuthor != null) 'book_author': bookAuthor,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (chapterPos != null) 'chapter_pos': chapterPos,
      if (content != null) 'content': content,
      if (createdTime != null) 'created_time': createdTime,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarkRecordsCompanion copyWith(
      {Value<String>? id,
      Value<String>? bookId,
      Value<String>? bookName,
      Value<String>? bookAuthor,
      Value<int>? chapterIndex,
      Value<String>? chapterTitle,
      Value<int>? chapterPos,
      Value<String>? content,
      Value<int>? createdTime,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return BookmarkRecordsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookName: bookName ?? this.bookName,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterPos: chapterPos ?? this.chapterPos,
      content: content ?? this.content,
      createdTime: createdTime ?? this.createdTime,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (bookName.present) {
      map['book_name'] = Variable<String>(bookName.value);
    }
    if (bookAuthor.present) {
      map['book_author'] = Variable<String>(bookAuthor.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (chapterPos.present) {
      map['chapter_pos'] = Variable<int>(chapterPos.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdTime.present) {
      map['created_time'] = Variable<int>(createdTime.value);
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
    return (StringBuffer('BookmarkRecordsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('bookName: $bookName, ')
          ..write('bookAuthor: $bookAuthor, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('chapterPos: $chapterPos, ')
          ..write('content: $content, ')
          ..write('createdTime: $createdTime, ')
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
  late final $BookRecordsTable bookRecords = $BookRecordsTable(this);
  late final $ChapterRecordsTable chapterRecords = $ChapterRecordsTable(this);
  late final $ReplaceRuleRecordsTable replaceRuleRecords =
      $ReplaceRuleRecordsTable(this);
  late final $AppKeyValueRecordsTable appKeyValueRecords =
      $AppKeyValueRecordsTable(this);
  late final $BookmarkRecordsTable bookmarkRecords =
      $BookmarkRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        sourceRecords,
        bookRecords,
        chapterRecords,
        replaceRuleRecords,
        appKeyValueRecords,
        bookmarkRecords
      ];
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
typedef $$BookRecordsTableCreateCompanionBuilder = BookRecordsCompanion
    Function({
  required String id,
  Value<String> title,
  Value<String> author,
  Value<String?> coverUrl,
  Value<String?> intro,
  Value<String?> sourceId,
  Value<String?> sourceUrl,
  Value<String?> latestChapter,
  Value<int> totalChapters,
  Value<int> currentChapter,
  Value<double> readProgress,
  Value<int?> lastReadTime,
  Value<int?> addedTime,
  Value<bool> isLocal,
  Value<String?> localPath,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$BookRecordsTableUpdateCompanionBuilder = BookRecordsCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> author,
  Value<String?> coverUrl,
  Value<String?> intro,
  Value<String?> sourceId,
  Value<String?> sourceUrl,
  Value<String?> latestChapter,
  Value<int> totalChapters,
  Value<int> currentChapter,
  Value<double> readProgress,
  Value<int?> lastReadTime,
  Value<int?> addedTime,
  Value<bool> isLocal,
  Value<String?> localPath,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$BookRecordsTableFilterComposer
    extends Composer<_$SourceDriftDatabase, $BookRecordsTable> {
  $$BookRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get intro => $composableBuilder(
      column: $table.intro, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceId => $composableBuilder(
      column: $table.sourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get latestChapter => $composableBuilder(
      column: $table.latestChapter, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalChapters => $composableBuilder(
      column: $table.totalChapters, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentChapter => $composableBuilder(
      column: $table.currentChapter,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get readProgress => $composableBuilder(
      column: $table.readProgress, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastReadTime => $composableBuilder(
      column: $table.lastReadTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get addedTime => $composableBuilder(
      column: $table.addedTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$BookRecordsTableOrderingComposer
    extends Composer<_$SourceDriftDatabase, $BookRecordsTable> {
  $$BookRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get intro => $composableBuilder(
      column: $table.intro, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceId => $composableBuilder(
      column: $table.sourceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get latestChapter => $composableBuilder(
      column: $table.latestChapter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalChapters => $composableBuilder(
      column: $table.totalChapters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentChapter => $composableBuilder(
      column: $table.currentChapter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get readProgress => $composableBuilder(
      column: $table.readProgress,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastReadTime => $composableBuilder(
      column: $table.lastReadTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get addedTime => $composableBuilder(
      column: $table.addedTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BookRecordsTableAnnotationComposer
    extends Composer<_$SourceDriftDatabase, $BookRecordsTable> {
  $$BookRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get intro =>
      $composableBuilder(column: $table.intro, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get latestChapter => $composableBuilder(
      column: $table.latestChapter, builder: (column) => column);

  GeneratedColumn<int> get totalChapters => $composableBuilder(
      column: $table.totalChapters, builder: (column) => column);

  GeneratedColumn<int> get currentChapter => $composableBuilder(
      column: $table.currentChapter, builder: (column) => column);

  GeneratedColumn<double> get readProgress => $composableBuilder(
      column: $table.readProgress, builder: (column) => column);

  GeneratedColumn<int> get lastReadTime => $composableBuilder(
      column: $table.lastReadTime, builder: (column) => column);

  GeneratedColumn<int> get addedTime =>
      $composableBuilder(column: $table.addedTime, builder: (column) => column);

  GeneratedColumn<bool> get isLocal =>
      $composableBuilder(column: $table.isLocal, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookRecordsTableTableManager extends RootTableManager<
    _$SourceDriftDatabase,
    $BookRecordsTable,
    BookRecord,
    $$BookRecordsTableFilterComposer,
    $$BookRecordsTableOrderingComposer,
    $$BookRecordsTableAnnotationComposer,
    $$BookRecordsTableCreateCompanionBuilder,
    $$BookRecordsTableUpdateCompanionBuilder,
    (
      BookRecord,
      BaseReferences<_$SourceDriftDatabase, $BookRecordsTable, BookRecord>
    ),
    BookRecord,
    PrefetchHooks Function()> {
  $$BookRecordsTableTableManager(
      _$SourceDriftDatabase db, $BookRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<String?> intro = const Value.absent(),
            Value<String?> sourceId = const Value.absent(),
            Value<String?> sourceUrl = const Value.absent(),
            Value<String?> latestChapter = const Value.absent(),
            Value<int> totalChapters = const Value.absent(),
            Value<int> currentChapter = const Value.absent(),
            Value<double> readProgress = const Value.absent(),
            Value<int?> lastReadTime = const Value.absent(),
            Value<int?> addedTime = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookRecordsCompanion(
            id: id,
            title: title,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            sourceId: sourceId,
            sourceUrl: sourceUrl,
            latestChapter: latestChapter,
            totalChapters: totalChapters,
            currentChapter: currentChapter,
            readProgress: readProgress,
            lastReadTime: lastReadTime,
            addedTime: addedTime,
            isLocal: isLocal,
            localPath: localPath,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<String?> intro = const Value.absent(),
            Value<String?> sourceId = const Value.absent(),
            Value<String?> sourceUrl = const Value.absent(),
            Value<String?> latestChapter = const Value.absent(),
            Value<int> totalChapters = const Value.absent(),
            Value<int> currentChapter = const Value.absent(),
            Value<double> readProgress = const Value.absent(),
            Value<int?> lastReadTime = const Value.absent(),
            Value<int?> addedTime = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookRecordsCompanion.insert(
            id: id,
            title: title,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            sourceId: sourceId,
            sourceUrl: sourceUrl,
            latestChapter: latestChapter,
            totalChapters: totalChapters,
            currentChapter: currentChapter,
            readProgress: readProgress,
            lastReadTime: lastReadTime,
            addedTime: addedTime,
            isLocal: isLocal,
            localPath: localPath,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BookRecordsTableProcessedTableManager = ProcessedTableManager<
    _$SourceDriftDatabase,
    $BookRecordsTable,
    BookRecord,
    $$BookRecordsTableFilterComposer,
    $$BookRecordsTableOrderingComposer,
    $$BookRecordsTableAnnotationComposer,
    $$BookRecordsTableCreateCompanionBuilder,
    $$BookRecordsTableUpdateCompanionBuilder,
    (
      BookRecord,
      BaseReferences<_$SourceDriftDatabase, $BookRecordsTable, BookRecord>
    ),
    BookRecord,
    PrefetchHooks Function()>;
typedef $$ChapterRecordsTableCreateCompanionBuilder = ChapterRecordsCompanion
    Function({
  required String id,
  required String bookId,
  Value<String> title,
  Value<String?> url,
  Value<int> chapterIndex,
  Value<bool> isDownloaded,
  Value<String?> content,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$ChapterRecordsTableUpdateCompanionBuilder = ChapterRecordsCompanion
    Function({
  Value<String> id,
  Value<String> bookId,
  Value<String> title,
  Value<String?> url,
  Value<int> chapterIndex,
  Value<bool> isDownloaded,
  Value<String?> content,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$ChapterRecordsTableFilterComposer
    extends Composer<_$SourceDriftDatabase, $ChapterRecordsTable> {
  $$ChapterRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ChapterRecordsTableOrderingComposer
    extends Composer<_$SourceDriftDatabase, $ChapterRecordsTable> {
  $$ChapterRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ChapterRecordsTableAnnotationComposer
    extends Composer<_$SourceDriftDatabase, $ChapterRecordsTable> {
  $$ChapterRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => column);

  GeneratedColumn<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChapterRecordsTableTableManager extends RootTableManager<
    _$SourceDriftDatabase,
    $ChapterRecordsTable,
    ChapterRecord,
    $$ChapterRecordsTableFilterComposer,
    $$ChapterRecordsTableOrderingComposer,
    $$ChapterRecordsTableAnnotationComposer,
    $$ChapterRecordsTableCreateCompanionBuilder,
    $$ChapterRecordsTableUpdateCompanionBuilder,
    (
      ChapterRecord,
      BaseReferences<_$SourceDriftDatabase, $ChapterRecordsTable, ChapterRecord>
    ),
    ChapterRecord,
    PrefetchHooks Function()> {
  $$ChapterRecordsTableTableManager(
      _$SourceDriftDatabase db, $ChapterRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChapterRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChapterRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChapterRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> url = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChapterRecordsCompanion(
            id: id,
            bookId: bookId,
            title: title,
            url: url,
            chapterIndex: chapterIndex,
            isDownloaded: isDownloaded,
            content: content,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String bookId,
            Value<String> title = const Value.absent(),
            Value<String?> url = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChapterRecordsCompanion.insert(
            id: id,
            bookId: bookId,
            title: title,
            url: url,
            chapterIndex: chapterIndex,
            isDownloaded: isDownloaded,
            content: content,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChapterRecordsTableProcessedTableManager = ProcessedTableManager<
    _$SourceDriftDatabase,
    $ChapterRecordsTable,
    ChapterRecord,
    $$ChapterRecordsTableFilterComposer,
    $$ChapterRecordsTableOrderingComposer,
    $$ChapterRecordsTableAnnotationComposer,
    $$ChapterRecordsTableCreateCompanionBuilder,
    $$ChapterRecordsTableUpdateCompanionBuilder,
    (
      ChapterRecord,
      BaseReferences<_$SourceDriftDatabase, $ChapterRecordsTable, ChapterRecord>
    ),
    ChapterRecord,
    PrefetchHooks Function()>;
typedef $$ReplaceRuleRecordsTableCreateCompanionBuilder
    = ReplaceRuleRecordsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> groupName,
  Value<String> pattern,
  Value<String> replacement,
  Value<String?> scope,
  Value<bool> scopeTitle,
  Value<bool> scopeContent,
  Value<String?> excludeScope,
  Value<bool> isEnabled,
  Value<bool> isRegex,
  Value<int> timeoutMillisecond,
  Value<int> orderValue,
  Value<int> updatedAt,
});
typedef $$ReplaceRuleRecordsTableUpdateCompanionBuilder
    = ReplaceRuleRecordsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> groupName,
  Value<String> pattern,
  Value<String> replacement,
  Value<String?> scope,
  Value<bool> scopeTitle,
  Value<bool> scopeContent,
  Value<String?> excludeScope,
  Value<bool> isEnabled,
  Value<bool> isRegex,
  Value<int> timeoutMillisecond,
  Value<int> orderValue,
  Value<int> updatedAt,
});

class $$ReplaceRuleRecordsTableFilterComposer
    extends Composer<_$SourceDriftDatabase, $ReplaceRuleRecordsTable> {
  $$ReplaceRuleRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupName => $composableBuilder(
      column: $table.groupName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pattern => $composableBuilder(
      column: $table.pattern, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replacement => $composableBuilder(
      column: $table.replacement, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get scopeTitle => $composableBuilder(
      column: $table.scopeTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get scopeContent => $composableBuilder(
      column: $table.scopeContent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get excludeScope => $composableBuilder(
      column: $table.excludeScope, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isEnabled => $composableBuilder(
      column: $table.isEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRegex => $composableBuilder(
      column: $table.isRegex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timeoutMillisecond => $composableBuilder(
      column: $table.timeoutMillisecond,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderValue => $composableBuilder(
      column: $table.orderValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ReplaceRuleRecordsTableOrderingComposer
    extends Composer<_$SourceDriftDatabase, $ReplaceRuleRecordsTable> {
  $$ReplaceRuleRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupName => $composableBuilder(
      column: $table.groupName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pattern => $composableBuilder(
      column: $table.pattern, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replacement => $composableBuilder(
      column: $table.replacement, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get scopeTitle => $composableBuilder(
      column: $table.scopeTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get scopeContent => $composableBuilder(
      column: $table.scopeContent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get excludeScope => $composableBuilder(
      column: $table.excludeScope,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
      column: $table.isEnabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRegex => $composableBuilder(
      column: $table.isRegex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timeoutMillisecond => $composableBuilder(
      column: $table.timeoutMillisecond,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderValue => $composableBuilder(
      column: $table.orderValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ReplaceRuleRecordsTableAnnotationComposer
    extends Composer<_$SourceDriftDatabase, $ReplaceRuleRecordsTable> {
  $$ReplaceRuleRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get replacement => $composableBuilder(
      column: $table.replacement, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<bool> get scopeTitle => $composableBuilder(
      column: $table.scopeTitle, builder: (column) => column);

  GeneratedColumn<bool> get scopeContent => $composableBuilder(
      column: $table.scopeContent, builder: (column) => column);

  GeneratedColumn<String> get excludeScope => $composableBuilder(
      column: $table.excludeScope, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<bool> get isRegex =>
      $composableBuilder(column: $table.isRegex, builder: (column) => column);

  GeneratedColumn<int> get timeoutMillisecond => $composableBuilder(
      column: $table.timeoutMillisecond, builder: (column) => column);

  GeneratedColumn<int> get orderValue => $composableBuilder(
      column: $table.orderValue, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReplaceRuleRecordsTableTableManager extends RootTableManager<
    _$SourceDriftDatabase,
    $ReplaceRuleRecordsTable,
    ReplaceRuleRecord,
    $$ReplaceRuleRecordsTableFilterComposer,
    $$ReplaceRuleRecordsTableOrderingComposer,
    $$ReplaceRuleRecordsTableAnnotationComposer,
    $$ReplaceRuleRecordsTableCreateCompanionBuilder,
    $$ReplaceRuleRecordsTableUpdateCompanionBuilder,
    (
      ReplaceRuleRecord,
      BaseReferences<_$SourceDriftDatabase, $ReplaceRuleRecordsTable,
          ReplaceRuleRecord>
    ),
    ReplaceRuleRecord,
    PrefetchHooks Function()> {
  $$ReplaceRuleRecordsTableTableManager(
      _$SourceDriftDatabase db, $ReplaceRuleRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReplaceRuleRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReplaceRuleRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReplaceRuleRecordsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> groupName = const Value.absent(),
            Value<String> pattern = const Value.absent(),
            Value<String> replacement = const Value.absent(),
            Value<String?> scope = const Value.absent(),
            Value<bool> scopeTitle = const Value.absent(),
            Value<bool> scopeContent = const Value.absent(),
            Value<String?> excludeScope = const Value.absent(),
            Value<bool> isEnabled = const Value.absent(),
            Value<bool> isRegex = const Value.absent(),
            Value<int> timeoutMillisecond = const Value.absent(),
            Value<int> orderValue = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
          }) =>
              ReplaceRuleRecordsCompanion(
            id: id,
            name: name,
            groupName: groupName,
            pattern: pattern,
            replacement: replacement,
            scope: scope,
            scopeTitle: scopeTitle,
            scopeContent: scopeContent,
            excludeScope: excludeScope,
            isEnabled: isEnabled,
            isRegex: isRegex,
            timeoutMillisecond: timeoutMillisecond,
            orderValue: orderValue,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> groupName = const Value.absent(),
            Value<String> pattern = const Value.absent(),
            Value<String> replacement = const Value.absent(),
            Value<String?> scope = const Value.absent(),
            Value<bool> scopeTitle = const Value.absent(),
            Value<bool> scopeContent = const Value.absent(),
            Value<String?> excludeScope = const Value.absent(),
            Value<bool> isEnabled = const Value.absent(),
            Value<bool> isRegex = const Value.absent(),
            Value<int> timeoutMillisecond = const Value.absent(),
            Value<int> orderValue = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
          }) =>
              ReplaceRuleRecordsCompanion.insert(
            id: id,
            name: name,
            groupName: groupName,
            pattern: pattern,
            replacement: replacement,
            scope: scope,
            scopeTitle: scopeTitle,
            scopeContent: scopeContent,
            excludeScope: excludeScope,
            isEnabled: isEnabled,
            isRegex: isRegex,
            timeoutMillisecond: timeoutMillisecond,
            orderValue: orderValue,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReplaceRuleRecordsTableProcessedTableManager = ProcessedTableManager<
    _$SourceDriftDatabase,
    $ReplaceRuleRecordsTable,
    ReplaceRuleRecord,
    $$ReplaceRuleRecordsTableFilterComposer,
    $$ReplaceRuleRecordsTableOrderingComposer,
    $$ReplaceRuleRecordsTableAnnotationComposer,
    $$ReplaceRuleRecordsTableCreateCompanionBuilder,
    $$ReplaceRuleRecordsTableUpdateCompanionBuilder,
    (
      ReplaceRuleRecord,
      BaseReferences<_$SourceDriftDatabase, $ReplaceRuleRecordsTable,
          ReplaceRuleRecord>
    ),
    ReplaceRuleRecord,
    PrefetchHooks Function()>;
typedef $$AppKeyValueRecordsTableCreateCompanionBuilder
    = AppKeyValueRecordsCompanion Function({
  required String key,
  Value<String?> value,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$AppKeyValueRecordsTableUpdateCompanionBuilder
    = AppKeyValueRecordsCompanion Function({
  Value<String> key,
  Value<String?> value,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$AppKeyValueRecordsTableFilterComposer
    extends Composer<_$SourceDriftDatabase, $AppKeyValueRecordsTable> {
  $$AppKeyValueRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AppKeyValueRecordsTableOrderingComposer
    extends Composer<_$SourceDriftDatabase, $AppKeyValueRecordsTable> {
  $$AppKeyValueRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AppKeyValueRecordsTableAnnotationComposer
    extends Composer<_$SourceDriftDatabase, $AppKeyValueRecordsTable> {
  $$AppKeyValueRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppKeyValueRecordsTableTableManager extends RootTableManager<
    _$SourceDriftDatabase,
    $AppKeyValueRecordsTable,
    AppKeyValueRecord,
    $$AppKeyValueRecordsTableFilterComposer,
    $$AppKeyValueRecordsTableOrderingComposer,
    $$AppKeyValueRecordsTableAnnotationComposer,
    $$AppKeyValueRecordsTableCreateCompanionBuilder,
    $$AppKeyValueRecordsTableUpdateCompanionBuilder,
    (
      AppKeyValueRecord,
      BaseReferences<_$SourceDriftDatabase, $AppKeyValueRecordsTable,
          AppKeyValueRecord>
    ),
    AppKeyValueRecord,
    PrefetchHooks Function()> {
  $$AppKeyValueRecordsTableTableManager(
      _$SourceDriftDatabase db, $AppKeyValueRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppKeyValueRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppKeyValueRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppKeyValueRecordsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String?> value = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppKeyValueRecordsCompanion(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            Value<String?> value = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppKeyValueRecordsCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppKeyValueRecordsTableProcessedTableManager = ProcessedTableManager<
    _$SourceDriftDatabase,
    $AppKeyValueRecordsTable,
    AppKeyValueRecord,
    $$AppKeyValueRecordsTableFilterComposer,
    $$AppKeyValueRecordsTableOrderingComposer,
    $$AppKeyValueRecordsTableAnnotationComposer,
    $$AppKeyValueRecordsTableCreateCompanionBuilder,
    $$AppKeyValueRecordsTableUpdateCompanionBuilder,
    (
      AppKeyValueRecord,
      BaseReferences<_$SourceDriftDatabase, $AppKeyValueRecordsTable,
          AppKeyValueRecord>
    ),
    AppKeyValueRecord,
    PrefetchHooks Function()>;
typedef $$BookmarkRecordsTableCreateCompanionBuilder = BookmarkRecordsCompanion
    Function({
  required String id,
  required String bookId,
  Value<String> bookName,
  Value<String> bookAuthor,
  Value<int> chapterIndex,
  Value<String> chapterTitle,
  Value<int> chapterPos,
  Value<String> content,
  Value<int> createdTime,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$BookmarkRecordsTableUpdateCompanionBuilder = BookmarkRecordsCompanion
    Function({
  Value<String> id,
  Value<String> bookId,
  Value<String> bookName,
  Value<String> bookAuthor,
  Value<int> chapterIndex,
  Value<String> chapterTitle,
  Value<int> chapterPos,
  Value<String> content,
  Value<int> createdTime,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$BookmarkRecordsTableFilterComposer
    extends Composer<_$SourceDriftDatabase, $BookmarkRecordsTable> {
  $$BookmarkRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookName => $composableBuilder(
      column: $table.bookName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookAuthor => $composableBuilder(
      column: $table.bookAuthor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chapterTitle => $composableBuilder(
      column: $table.chapterTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterPos => $composableBuilder(
      column: $table.chapterPos, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdTime => $composableBuilder(
      column: $table.createdTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$BookmarkRecordsTableOrderingComposer
    extends Composer<_$SourceDriftDatabase, $BookmarkRecordsTable> {
  $$BookmarkRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookName => $composableBuilder(
      column: $table.bookName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookAuthor => $composableBuilder(
      column: $table.bookAuthor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
      column: $table.chapterTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterPos => $composableBuilder(
      column: $table.chapterPos, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdTime => $composableBuilder(
      column: $table.createdTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BookmarkRecordsTableAnnotationComposer
    extends Composer<_$SourceDriftDatabase, $BookmarkRecordsTable> {
  $$BookmarkRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get bookName =>
      $composableBuilder(column: $table.bookName, builder: (column) => column);

  GeneratedColumn<String> get bookAuthor => $composableBuilder(
      column: $table.bookAuthor, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => column);

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
      column: $table.chapterTitle, builder: (column) => column);

  GeneratedColumn<int> get chapterPos => $composableBuilder(
      column: $table.chapterPos, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get createdTime => $composableBuilder(
      column: $table.createdTime, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookmarkRecordsTableTableManager extends RootTableManager<
    _$SourceDriftDatabase,
    $BookmarkRecordsTable,
    BookmarkRecord,
    $$BookmarkRecordsTableFilterComposer,
    $$BookmarkRecordsTableOrderingComposer,
    $$BookmarkRecordsTableAnnotationComposer,
    $$BookmarkRecordsTableCreateCompanionBuilder,
    $$BookmarkRecordsTableUpdateCompanionBuilder,
    (
      BookmarkRecord,
      BaseReferences<_$SourceDriftDatabase, $BookmarkRecordsTable,
          BookmarkRecord>
    ),
    BookmarkRecord,
    PrefetchHooks Function()> {
  $$BookmarkRecordsTableTableManager(
      _$SourceDriftDatabase db, $BookmarkRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarkRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarkRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarkRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> bookName = const Value.absent(),
            Value<String> bookAuthor = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<String> chapterTitle = const Value.absent(),
            Value<int> chapterPos = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<int> createdTime = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookmarkRecordsCompanion(
            id: id,
            bookId: bookId,
            bookName: bookName,
            bookAuthor: bookAuthor,
            chapterIndex: chapterIndex,
            chapterTitle: chapterTitle,
            chapterPos: chapterPos,
            content: content,
            createdTime: createdTime,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String bookId,
            Value<String> bookName = const Value.absent(),
            Value<String> bookAuthor = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<String> chapterTitle = const Value.absent(),
            Value<int> chapterPos = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<int> createdTime = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookmarkRecordsCompanion.insert(
            id: id,
            bookId: bookId,
            bookName: bookName,
            bookAuthor: bookAuthor,
            chapterIndex: chapterIndex,
            chapterTitle: chapterTitle,
            chapterPos: chapterPos,
            content: content,
            createdTime: createdTime,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BookmarkRecordsTableProcessedTableManager = ProcessedTableManager<
    _$SourceDriftDatabase,
    $BookmarkRecordsTable,
    BookmarkRecord,
    $$BookmarkRecordsTableFilterComposer,
    $$BookmarkRecordsTableOrderingComposer,
    $$BookmarkRecordsTableAnnotationComposer,
    $$BookmarkRecordsTableCreateCompanionBuilder,
    $$BookmarkRecordsTableUpdateCompanionBuilder,
    (
      BookmarkRecord,
      BaseReferences<_$SourceDriftDatabase, $BookmarkRecordsTable,
          BookmarkRecord>
    ),
    BookmarkRecord,
    PrefetchHooks Function()>;

class $SourceDriftDatabaseManager {
  final _$SourceDriftDatabase _db;
  $SourceDriftDatabaseManager(this._db);
  $$SourceRecordsTableTableManager get sourceRecords =>
      $$SourceRecordsTableTableManager(_db, _db.sourceRecords);
  $$BookRecordsTableTableManager get bookRecords =>
      $$BookRecordsTableTableManager(_db, _db.bookRecords);
  $$ChapterRecordsTableTableManager get chapterRecords =>
      $$ChapterRecordsTableTableManager(_db, _db.chapterRecords);
  $$ReplaceRuleRecordsTableTableManager get replaceRuleRecords =>
      $$ReplaceRuleRecordsTableTableManager(_db, _db.replaceRuleRecords);
  $$AppKeyValueRecordsTableTableManager get appKeyValueRecords =>
      $$AppKeyValueRecordsTableTableManager(_db, _db.appKeyValueRecords);
  $$BookmarkRecordsTableTableManager get bookmarkRecords =>
      $$BookmarkRecordsTableTableManager(_db, _db.bookmarkRecords);
}
