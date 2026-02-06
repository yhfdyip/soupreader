import 'package:hive_flutter/hive_flutter.dart';
import 'entities/book_entity.dart';

/// 数据库服务 - 管理 Hive 初始化和 Box 访问
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _booksBoxName = 'books';
  static const String _chaptersBoxName = 'chapters';
  static const String _sourcesBoxName = 'sources';
  static const String _replaceRulesBoxName = 'replace_rules';
  static const String _settingsBoxName = 'settings';

  late Box<BookEntity> _booksBox;
  late Box<ChapterEntity> _chaptersBox;
  late Box<BookSourceEntity> _sourcesBox;
  late Box<ReplaceRuleEntity> _replaceRulesBox;
  late Box<dynamic> _settingsBox;

  bool _isInitialized = false;

  /// 初始化数据库
  Future<void> init() async {
    if (_isInitialized) return;

    // 初始化 Hive
    await Hive.initFlutter();

    // 注册适配器
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BookEntityAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ChapterEntityAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(BookSourceEntityAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ReplaceRuleEntityAdapter());
    }

    // 打开 Box
    _booksBox = await Hive.openBox<BookEntity>(_booksBoxName);
    _chaptersBox = await Hive.openBox<ChapterEntity>(_chaptersBoxName);
    _sourcesBox = await Hive.openBox<BookSourceEntity>(_sourcesBoxName);
    _replaceRulesBox =
        await Hive.openBox<ReplaceRuleEntity>(_replaceRulesBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);

    _isInitialized = true;
  }

  /// 获取书籍 Box
  Box<BookEntity> get booksBox {
    _checkInitialized();
    return _booksBox;
  }

  /// 获取章节 Box
  Box<ChapterEntity> get chaptersBox {
    _checkInitialized();
    return _chaptersBox;
  }

  /// 获取书源 Box
  Box<BookSourceEntity> get sourcesBox {
    _checkInitialized();
    return _sourcesBox;
  }

  Box<ReplaceRuleEntity> get replaceRulesBox {
    _checkInitialized();
    return _replaceRulesBox;
  }

  /// 获取设置 Box
  Box<dynamic> get settingsBox {
    _checkInitialized();
    return _settingsBox;
  }

  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError('DatabaseService 未初始化，请先调用 init()');
    }
  }

  /// 清空所有数据
  Future<void> clearAll() async {
    await _booksBox.clear();
    await _chaptersBox.clear();
    await _sourcesBox.clear();
    await _replaceRulesBox.clear();
    await _settingsBox.clear();
  }

  /// 关闭数据库
  Future<void> close() async {
    await Hive.close();
    _isInitialized = false;
  }
}
