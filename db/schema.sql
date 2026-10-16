-- ============================================================
-- 今天吃什么 · V2.0 B 阶段 建表脚本（MySQL 8）
-- 作者：DB 会话（数据库全流程负责人）
-- 日期：2026-10-13
-- 依据：docs/01-设计终稿.md §7.1（V2-B 表设计修订 · HP-V22）
--
-- 表清单（共 10 张）
--   基础表 3：users / dishes / tags
--   从表   4：user_profiles / dining_companions / dish_options / pick_history
--   中间表 3：dish_tags / companion_avoid_tags / user_preference_tags
--
-- 【执行前须知】执行本脚本要项目负责人明确同意：
--   1) 脚本含 CREATE DATABASE，会在 MySQL 里新建一个库（不动现有任何数据）
--   2) 脚本不含任何 DROP / DELETE / TRUNCATE，但重复执行会因表已存在而报错
--   3) 数据库名：today_eat_what
--
-- 【与 §7.1 的一致性说明】（DB 会话填写，供 HP-V22 核对）
--   - 已按决策 6 完成 SQLite → MySQL 8 转写：
--       INTEGER PRIMARY KEY AUTOINCREMENT -> INT NOT NULL AUTO_INCREMENT PRIMARY KEY
--       每张表补 ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
--       pick_history 补上主键 id（原稿漏）
--   - 已按决策 1 新增第 10 张表 dish_options
--   - 已按决策 4 把 tags.category 扩为 6 类（新增 meal）；再按决策 10 扩为 7 类（新增 type）
--       已建好的库用 ALTER 改 CHECK，不要 DROP 重建（改结构不删数据）
--   - 【维护提醒】2026-10-14 发现本文件 tags 部分的「7 类」改动曾被回退成 6 类（其余改动未受影响）；
--       要改本文件请先告知 DB 会话，否则两边会互相覆盖——db/ 尚未纳入 git，覆盖了无版本可查
--   - 已按决策 5 在 user_profiles 增加 meal_period
--   - 【已定稿（决策 1 · 2026-10-13 负责人拍板）】dish_options.option_value 存文本（VARCHAR），
--       不指向 tags.id —— 可调值是另一类东西，避免「微辣 / 中辣」这类纯档位污染 tags.category 的语义
--   - 【spicy 收紧】dishes.spicy 建成 NOT NULL DEFAULT 0：
--       决策 2 已明确「永远有值，不辣的菜为 0」，可空会让 CHECK 出现「UNKNOWN 即通过」的模糊地带
--   - 【两处轻微增强，可删，删掉不影响其它表】
--       a) user_profiles.updated_at 加 ON UPDATE CURRENT_TIMESTAMP
--          （不加的话它永远等于创建时间，"最后更新时间"名不副实）
--       b) tags.category 加 CHECK 枚举（决策 4 + 10 已明确 7 个取值）
--       注：user_preference_tags.kind 故意不加 CHECK，因为决策 5 预留了将来的 kind='meal'
--   - 【pick_history 的删除行为（决策 8）】两个外键用 ON DELETE SET NULL（不是 CASCADE）：
--       删用户 / 菜下架时，历史记录保留、对应列置空，保证「只增不改」的流水不被连带清掉；
--       代价是该两列必须允许 NULL，以后查历史要处理「无主记录」
--   - 【未额外建索引】外键会自动带索引；本项目数据量小，按需再加
-- ============================================================

CREATE DATABASE IF NOT EXISTS today_eat_what
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE today_eat_what;

-- ------------------------------------------------------------
-- 1. users 用户表
--    生活比喻：户口本的一页，一个人占一行
-- ------------------------------------------------------------
CREATE TABLE users (
  id          INT NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '用户ID，自动编号',
  username    VARCHAR(50) NOT NULL COMMENT '用户名，唯一且必填',
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  UNIQUE KEY uk_users_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户表（V2.0 不实现登录，先建好）';


-- ------------------------------------------------------------
-- 2. dishes 菜品表
--    只存「这道菜本身不会变的东西」；可调属性不在这里
-- ------------------------------------------------------------
CREATE TABLE dishes (
  id          INT NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '菜品ID，自动编号',
  name        VARCHAR(50) NOT NULL COMMENT '菜名，唯一且必填',
  price       DECIMAL(6,2) COMMENT '静态参考价（不进模型，决策 3）',
  calories    INT COMMENT '热量，单位 kcal',
  spicy       TINYINT NOT NULL DEFAULT 0 COMMENT '基础辣度 0-5，不辣的菜为 0（决策 2）',
  heaviness   VARCHAR(10) COMMENT '轻重：light|medium|heavy',
  serving     VARCHAR(10) DEFAULT 'single' COMMENT 'single|share，默认 single',
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  UNIQUE KEY uk_dishes_name (name),
  CONSTRAINT chk_dishes_spicy     CHECK (spicy BETWEEN 0 AND 5),
  CONSTRAINT chk_dishes_heaviness CHECK (heaviness IN ('light','medium','heavy')),
  CONSTRAINT chk_dishes_serving   CHECK (serving IN ('single','share'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='菜品表';


-- ------------------------------------------------------------
-- 3. tags 标签表`today_eat_what`
--    一张表统管所有「形容词」，靠 category 分 7 栏
-- ------------------------------------------------------------
CREATE TABLE tags (
  id        INT NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '标签ID，自动编号',
  name      VARCHAR(20) NOT NULL COMMENT '标签名，如 川菜 / 微辣 / 晚餐',
  category  VARCHAR(20) NOT NULL COMMENT '7 类：cuisine|taste|health|mood|ingredient|meal|type（决策 4 + 10）',
  UNIQUE KEY uk_tags_name_category (name, category),
  CONSTRAINT chk_tags_category CHECK (category IN
    ('cuisine','taste','health','mood','ingredient','meal','type'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='标签表：共享词库，菜/用户/搭子都引用它';


-- ------------------------------------------------------------
-- 4. user_profiles 用户画像
--    user_id 既是主键又是外键 → 数据库层面保证「一人只一份」
-- ------------------------------------------------------------
CREATE TABLE user_profiles (
  user_id       INT NOT NULL PRIMARY KEY COMMENT '用户ID：既是主键又是外键，一人只一份',
  hometown      VARCHAR(20) COMMENT '家乡（底层口味）',
  current_city  VARCHAR(20) COMMENT '现居地（现实供给）',
  budget        DECIMAL(6,2) COMMENT '这餐预算',
  mood          VARCHAR(20) COMMENT '当前心情（本次可改的上下文）',
  headcount     TINYINT DEFAULT 1 COMMENT '用餐人数，默认 1',
  portion_size  VARCHAR(5) COMMENT '饭量：小/中/大',
  age_range     VARCHAR(10) COMMENT '年龄段（不参与规则打分）',
  gender        VARCHAR(10) COMMENT '性别（不参与规则打分）',
  meal_period   VARCHAR(10) COMMENT '本餐时段，与 mood 同级（决策 5）',
  updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最后更新时间',
  CONSTRAINT fk_user_profiles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户画像：与 users 一对一';


-- ------------------------------------------------------------
-- 5. dish_tags 菜品 ⇄ 标签（N:M）
--    一行 = 「这道菜贴了这个标签」这一个事实
-- ------------------------------------------------------------
CREATE TABLE dish_tags (
  dish_id  INT NOT NULL COMMENT '菜品ID → dishes.id',
  tag_id   INT NOT NULL COMMENT '标签ID → tags.id',
  PRIMARY KEY (dish_id, tag_id),
  CONSTRAINT fk_dish_tags_dish FOREIGN KEY (dish_id) REFERENCES dishes(id) ON DELETE CASCADE,
  CONSTRAINT fk_dish_tags_tag  FOREIGN KEY (tag_id)  REFERENCES tags(id)   ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='中间表：菜品 ⇄ 标签';


-- ------------------------------------------------------------
-- 6. dish_options 菜品可调属性（明细表，不是中间表）
--    规矩：有行 = 该属性可调；没行 = 固定不可调
-- ------------------------------------------------------------
CREATE TABLE dish_options (
  id            INT NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '选项ID，自动编号',
  dish_id       INT NOT NULL COMMENT '菜品ID → dishes.id',
  option_name   VARCHAR(20) NOT NULL COMMENT '可调属性名：spicy_level|soup_base|cilantro|portion',
  option_value  VARCHAR(20) NOT NULL COMMENT '可选取值，如 中辣 / 清汤（决策 1：存文本，已定稿）',
  is_default    TINYINT(1) DEFAULT 0 COMMENT '是否默认取值：1=是，0=否',
  extra_price   DECIMAL(6,2) DEFAULT 0 COMMENT '加料加价，通常 0',
  UNIQUE KEY uk_dish_options (dish_id, option_name, option_value),
  CONSTRAINT fk_dish_options_dish FOREIGN KEY (dish_id) REFERENCES dishes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='菜品可调属性（决策 1：属性的可变性）';


-- ------------------------------------------------------------
-- 7. dining_companions 搭子表（1:N）
--    搭子不是系统用户，所以不能塞进 users
-- ------------------------------------------------------------
CREATE TABLE dining_companions (
  id       INT NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '搭子ID，自动编号',
  user_id  INT NOT NULL COMMENT '这是谁的搭子 → users.id',
  name     VARCHAR(30) NOT NULL COMMENT '搭子称呼，如 小明',
  CONSTRAINT fk_dining_companions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='搭子表：一个用户有多个搭子';


-- ------------------------------------------------------------
-- 8. companion_avoid_tags 搭子 ⇄ 忌口标签（N:M）
-- ------------------------------------------------------------
CREATE TABLE companion_avoid_tags (
  companion_id INT NOT NULL COMMENT '搭子ID → dining_companions.id',
  tag_id       INT NOT NULL COMMENT '忌口标签ID → tags.id',
  PRIMARY KEY (companion_id, tag_id),
  CONSTRAINT fk_companion_avoid_companion FOREIGN KEY (companion_id) REFERENCES dining_companions(id) ON DELETE CASCADE,
  CONSTRAINT fk_companion_avoid_tag       FOREIGN KEY (tag_id)       REFERENCES tags(id)              ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='中间表：搭子 ⇄ 忌口标签';


-- ------------------------------------------------------------
-- 9. user_preference_tags 用户 ⇄ 标签（N:M）
--    比另两张中间表多一个 kind，区分「喜欢」和「忌口」
-- ------------------------------------------------------------
CREATE TABLE user_preference_tags (
  user_id  INT NOT NULL COMMENT '用户ID → users.id',
  tag_id   INT NOT NULL COMMENT '标签ID → tags.id',
  kind     VARCHAR(10) NOT NULL COMMENT '用途：taste|goal|avoid_hard|avoid_soft（预留 meal，故不设 CHECK）',
  PRIMARY KEY (user_id, tag_id, kind),
  CONSTRAINT fk_user_pref_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_user_pref_tag  FOREIGN KEY (tag_id)  REFERENCES tags(id)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='中间表：用户 ⇄ 标签，靠 kind 区分用途';


-- ------------------------------------------------------------
-- 10. pick_history 抽取历史
--     只增不改的流水账；原稿缺主键，本次补上（决策 6）
--     两个外键用 ON DELETE SET NULL（决策 8）：删用户 / 菜下架时，历史留下、该列置空
-- ------------------------------------------------------------
CREATE TABLE pick_history (
  id          INT NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '记录ID：原稿漏主键，本次补上',
  user_id     INT NULL COMMENT '谁抽的 → users.id（可空：删用户时置空，历史留下）',
  dish_id     INT NULL COMMENT '抽到哪道菜 → dishes.id（可空：菜下架时置空，历史留下）',
  source      VARCHAR(10) COMMENT '来源：llm|rule|random',
  strategy    VARCHAR(10) COMMENT '策略：exploit|explore|fallback',
  reason      TEXT COMMENT '推荐理由',
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '抽取时间',
  CONSTRAINT fk_pick_history_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_pick_history_dish FOREIGN KEY (dish_id) REFERENCES dishes(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='抽取历史流水：V3.0 长期记忆的地基';


-- ============================================================
-- 执行后的自查（手动跑这几条，别猜）
--   SHOW TABLES;                                   -- 应该正好 10 张
--   SELECT COUNT(*) FROM information_schema.tables
--     WHERE table_schema='today_eat_what';         -- 应该返回 10
--   SHOW CREATE TABLE user_profiles;               -- 看 user_id 是不是既 PK 又 FK
--   SHOW CREATE TABLE dish_tags;                   -- 看联合主键和两个外键
-- ============================================================
