-- ============================================================
-- 今天吃什么 · V2.0 B-4 种子数据（seed.sql）
-- 作者：DB 会话（数据库全流程负责人）
-- 日期：2026-10-13（第一 ~ 第四节）／2026-10-14 补第五节画像值
-- 依据：docs/17-B4入库内容.md 第一 ~ 第五节（负责人判断，HP-V22 整理）
--       菜品基础字段取自 frontend/index.html 的 DEFAULT_DISHES（V1 原始数据）
--       —— 文档第二节只给了时段标签，dishes 本身的价格/热量/辣度取自 V1 源码
--       第五节画像值由项目负责人 2026-10-14 口述给出
--
-- 【执行前必读】
--   1) 本脚本只做 INSERT，不含任何 DROP / DELETE / TRUNCATE / UPDATE
--   2) 在空库上执行；重复执行会因 UNIQUE 约束报错（这是故意的，防止脏数据）
--   3) 中文入库必须带字符集参数（否则会出现问号乱码）：
--        mysql --default-character-set=utf8mb4 -u root -p today_eat_what < db/seed.sql
--   4) 第五节已写入（users 1 行 + user_profiles 1 行）；
--      user_preference_tags / dining_companions / companion_avoid_tags 本次为空，属有意为之
--
-- 【实际行数】2026-10-16 执行完成，项目负责人本人核对通过（四个数字与预期一致）
--   tags         46 行  ← HP 已确认文档里的「47」为心算错，46 是终值
--   dishes       12 行
--   dish_options 33 行
--   dish_tags    55 行
--   users         1 行
--   user_profiles 1 行
--   执行记录：dishes / dish_options / users / user_profiles 在 ALTER 前已入库成功；
--             tags 与 dish_tags 被旧 CHECK（6 类）拦住 type 类目而失败，
--             ALTER 把 CHECK 改成 7 类后，单独重跑这两块通过（未重跑整脚本，避免 1062 撞主键）
--
-- 【tags 行数已定稿：46 条（2026-10-16）】
--   文档标题曾写「共 47 行」，HP 已确认那是心算错误，46 是终值。
--   不要拆「牛羊肉」——拆了会变成 47 条，反而坐实那个错数字。
--   逐类核对：cuisine 6 + taste 4 + health 3 + mood 5 + ingredient 17 + meal 5 + type 6 = 46

-- ============================================================

USE today_eat_what;


-- ============================================================
-- 一、标签词表 tags（7 类）
-- ============================================================
INSERT INTO tags (name, category) VALUES
-- cuisine（6）
('川湘','cuisine'), ('北方','cuisine'), ('西北','cuisine'),
('西式','cuisine'), ('日韩','cuisine'), ('其他','cuisine'),
-- taste（4）
('川味','taste'), ('重口','taste'), ('清淡','taste'), ('辣','taste'),
-- health（3）：只给用户目标用，不挂在菜上
('减脂','health'), ('增肌','health'), ('控糖','health'),
-- mood（5）
('低落','mood'), ('想解压','mood'), ('没胃口','mood'), ('想犒劳自己','mood'), ('开心','mood'),
-- ingredient（17）
('花生','ingredient'), ('海鲜','ingredient'), ('牛羊肉','ingredient'), ('猪肉','ingredient'),
('鸡蛋','ingredient'), ('牛奶','ingredient'), ('香菜','ingredient'), ('内脏','ingredient'),
('葱','ingredient'), ('蒜','ingredient'), ('姜','ingredient'), ('萝卜','ingredient'),
('芹菜','ingredient'), ('韭菜','ingredient'), ('香菇','ingredient'), ('青椒','ingredient'),
('洋葱','ingredient'),
-- meal（5）
('早餐','meal'), ('午餐','meal'), ('晚餐','meal'), ('下午茶','meal'), ('夜宵','meal'),
-- type（6，决策 10 新增类目）
('饭','type'), ('面','type'), ('粉','type'), ('汤','type'), ('炸物','type'), ('轻食','type');


-- ============================================================
-- 二、12 道菜 dishes
--    字段来源：frontend/index.html 第 218~229 行 DEFAULT_DISHES
--    cuisine 不进这张表（它是标签，走第四节的 dish_tags）
-- ============================================================
INSERT INTO dishes (name, price, calories, spicy, heaviness, serving) VALUES
('麻辣烫',     18.00, 550, 3, 'heavy',  'single'),
('黄焖鸡米饭', 20.00, 600, 1, 'medium', 'single'),
('番茄鸡蛋面', 15.00, 450, 0, 'light',  'single'),
('螺蛳粉',     16.00, 500, 4, 'heavy',  'single'),
('盖浇饭',     18.00, 600, 1, 'medium', 'single'),
('兰州拉面',   17.00, 480, 0, 'medium', 'single'),
('汉堡套餐',   25.00, 750, 0, 'heavy',  'single'),
('寿司',       28.00, 350, 0, 'light',  'single'),
('炸鸡',       24.00, 800, 1, 'heavy',  'share'),
('饺子',       16.00, 450, 0, 'medium', 'single'),
('烤肉饭',     22.00, 680, 2, 'heavy',  'single'),
('沙拉',       21.00, 180, 0, 'light',  'single');


-- ============================================================
-- 三、菜 ⇄ 标签 dish_tags（55 行）
--    写法说明：菜名和标签名是给人看的，id 是自增的
--    所以用「临时小表 + JOIN 名称」的方式插，避免写死 id
--    每道菜一条语句，方便你逐道核对
-- ============================================================

-- 麻辣烫：cuisine 1 + type 1 + taste 2 + meal 3 = 7 行
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '麻辣烫' AS dish_name, '川湘' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '麻辣烫', '汤',   'type'
  UNION ALL SELECT '麻辣烫', '川味', 'taste'
  UNION ALL SELECT '麻辣烫', '重口', 'taste'
  UNION ALL SELECT '麻辣烫', '午餐', 'meal'
  UNION ALL SELECT '麻辣烫', '晚餐', 'meal'
  UNION ALL SELECT '麻辣烫', '夜宵', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 黄焖鸡米饭：cuisine 1 + type 1 + meal 2 = 4 行
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '黄焖鸡米饭' AS dish_name, '北方' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '黄焖鸡米饭', '饭',   'type'
  UNION ALL SELECT '黄焖鸡米饭', '午餐', 'meal'
  UNION ALL SELECT '黄焖鸡米饭', '晚餐', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 番茄鸡蛋面：cuisine 1 + type 1 + meal 3 = 5 行
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '番茄鸡蛋面' AS dish_name, '北方' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '番茄鸡蛋面', '面',   'type'
  UNION ALL SELECT '番茄鸡蛋面', '早餐', 'meal'
  UNION ALL SELECT '番茄鸡蛋面', '午餐', 'meal'
  UNION ALL SELECT '番茄鸡蛋面', '晚餐', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 螺蛳粉：cuisine 1 + type 1 + taste 1 + meal 3 = 6 行
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '螺蛳粉' AS dish_name, '其他' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '螺蛳粉', '粉',   'type'
  UNION ALL SELECT '螺蛳粉', '重口', 'taste'
  UNION ALL SELECT '螺蛳粉', '午餐', 'meal'
  UNION ALL SELECT '螺蛳粉', '晚餐', 'meal'
  UNION ALL SELECT '螺蛳粉', '夜宵', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 盖浇饭：cuisine 1 + type 1 + meal 2 = 4 行
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '盖浇饭' AS dish_name, '北方' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '盖浇饭', '饭',   'type'
  UNION ALL SELECT '盖浇饭', '午餐', 'meal'
  UNION ALL SELECT '盖浇饭', '晚餐', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 兰州拉面：cuisine 1 + type 1 + meal 3 = 5 行
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '兰州拉面' AS dish_name, '西北' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '兰州拉面', '面',   'type'
  UNION ALL SELECT '兰州拉面', '早餐', 'meal'
  UNION ALL SELECT '兰州拉面', '午餐', 'meal'
  UNION ALL SELECT '兰州拉面', '晚餐', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 汉堡套餐：cuisine 1 + meal 2 = 3 行（type 留空：套不上六个值）
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '汉堡套餐' AS dish_name, '西式' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '汉堡套餐', '午餐', 'meal'
  UNION ALL SELECT '汉堡套餐', '晚餐', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 寿司：cuisine 1 + meal 2 = 3 行（type 留空）
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '寿司' AS dish_name, '日韩' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '寿司', '午餐', 'meal'
  UNION ALL SELECT '寿司', '晚餐', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 炸鸡：cuisine 1 + type 1 + meal 3 = 5 行
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '炸鸡' AS dish_name, '西式' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '炸鸡', '炸物', 'type'
  UNION ALL SELECT '炸鸡', '下午茶', 'meal'
  UNION ALL SELECT '炸鸡', '晚餐',   'meal'
  UNION ALL SELECT '炸鸡', '夜宵',   'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 饺子：cuisine 1 + meal 3 = 4 行（type 留空）
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '饺子' AS dish_name, '北方' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '饺子', '早餐', 'meal'
  UNION ALL SELECT '饺子', '午餐', 'meal'
  UNION ALL SELECT '饺子', '晚餐', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 烤肉饭：cuisine 1 + type 1 + meal 2 = 4 行
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '烤肉饭' AS dish_name, '其他' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '烤肉饭', '饭',   'type'
  UNION ALL SELECT '烤肉饭', '午餐', 'meal'
  UNION ALL SELECT '烤肉饭', '晚餐', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;

-- 沙拉：cuisine 1 + type 1 + meal 3 = 5 行
INSERT INTO dish_tags (dish_id, tag_id)
SELECT d.id, t.id FROM (
            SELECT '沙拉' AS dish_name, '西式' AS tag_name, 'cuisine' AS tag_cat
  UNION ALL SELECT '沙拉', '轻食', 'type'
  UNION ALL SELECT '沙拉', '早餐', 'meal'
  UNION ALL SELECT '沙拉', '午餐', 'meal'
  UNION ALL SELECT '沙拉', '晚餐', 'meal'
) m JOIN dishes d ON d.name = m.dish_name
    JOIN tags   t ON t.name = m.tag_name AND t.category = m.tag_cat;


-- ============================================================
-- 四、菜的可调项 dish_options（33 行）
--    规则：每个「菜 × 属性」的第一个值为默认（is_default = 1），其余 0
--          extra_price 全为 0
--    规矩：有行 = 可调；没行 = 固定（沙拉没有 spicy_level 行 = 不能选辣度）
-- ============================================================

-- 麻辣烫：soup_base 2 + spicy_level 3 + cilantro 2 = 7 行
INSERT INTO dish_options (dish_id, option_name, option_value, is_default, extra_price)
SELECT d.id, m.option_name, m.option_value, m.is_default, 0 FROM (
            SELECT 'soup_base'   AS option_name, '清汤'   AS option_value, 1 AS is_default
  UNION ALL SELECT 'soup_base',   '麻辣',   0
  UNION ALL SELECT 'spicy_level', '微辣',   1
  UNION ALL SELECT 'spicy_level', '中辣',   0
  UNION ALL SELECT 'spicy_level', '重辣',   0
  UNION ALL SELECT 'cilantro',    '要香菜', 1
  UNION ALL SELECT 'cilantro',    '免香菜', 0
) m JOIN dishes d ON d.name = '麻辣烫';

-- 黄焖鸡米饭：spicy_level 3 = 3 行
INSERT INTO dish_options (dish_id, option_name, option_value, is_default, extra_price)
SELECT d.id, m.option_name, m.option_value, m.is_default, 0 FROM (
            SELECT 'spicy_level' AS option_name, '不辣' AS option_value, 1 AS is_default
  UNION ALL SELECT 'spicy_level', '微辣', 0
  UNION ALL SELECT 'spicy_level', '中辣', 0
) m JOIN dishes d ON d.name = '黄焖鸡米饭';

-- 番茄鸡蛋面：spicy_level 3 = 3 行（原有的「不可选口味」已废弃，不写进值里）
INSERT INTO dish_options (dish_id, option_name, option_value, is_default, extra_price)
SELECT d.id, m.option_name, m.option_value, m.is_default, 0 FROM (
            SELECT 'spicy_level' AS option_name, '不辣' AS option_value, 1 AS is_default
  UNION ALL SELECT 'spicy_level', '微辣', 0
  UNION ALL SELECT 'spicy_level', '中辣', 0
) m JOIN dishes d ON d.name = '番茄鸡蛋面';

-- 螺蛳粉：spicy_level 3 + cilantro 2 = 5 行
INSERT INTO dish_options (dish_id, option_name, option_value, is_default, extra_price)
SELECT d.id, m.option_name, m.option_value, m.is_default, 0 FROM (
            SELECT 'spicy_level' AS option_name, '微辣'   AS option_value, 1 AS is_default
  UNION ALL SELECT 'spicy_level', '中辣',   0
  UNION ALL SELECT 'spicy_level', '重辣',   0
  UNION ALL SELECT 'cilantro',    '要香菜', 1
  UNION ALL SELECT 'cilantro',    '免香菜', 0
) m JOIN dishes d ON d.name = '螺蛳粉';

-- 兰州拉面：spicy_level 3 + cilantro 2 + portion 2 = 7 行
INSERT INTO dish_options (dish_id, option_name, option_value, is_default, extra_price)
SELECT d.id, m.option_name, m.option_value, m.is_default, 0 FROM (
            SELECT 'spicy_level' AS option_name, '不辣'   AS option_value, 1 AS is_default
  UNION ALL SELECT 'spicy_level', '微辣',   0
  UNION ALL SELECT 'spicy_level', '中辣',   0
  UNION ALL SELECT 'cilantro',    '要香菜', 1
  UNION ALL SELECT 'cilantro',    '免香菜', 0
  UNION ALL SELECT 'portion',     '面多',   1
  UNION ALL SELECT 'portion',     '面少',   0
) m JOIN dishes d ON d.name = '兰州拉面';

-- 炸鸡：spicy_level 3 + sauce 2 = 5 行（原「原味/重辣」按四档词统一）
INSERT INTO dish_options (dish_id, option_name, option_value, is_default, extra_price)
SELECT d.id, m.option_name, m.option_value, m.is_default, 0 FROM (
            SELECT 'spicy_level' AS option_name, '不辣' AS option_value, 1 AS is_default
  UNION ALL SELECT 'spicy_level', '微辣', 0
  UNION ALL SELECT 'spicy_level', '重辣', 0
  UNION ALL SELECT 'sauce',       '原味', 1
  UNION ALL SELECT 'sauce',       '甜辣', 0
) m JOIN dishes d ON d.name = '炸鸡';

-- 沙拉：sauce 3 = 3 行（没有 spicy_level = 这道菜不能调辣度）
INSERT INTO dish_options (dish_id, option_name, option_value, is_default, extra_price)
SELECT d.id, m.option_name, m.option_value, m.is_default, 0 FROM (
            SELECT 'sauce' AS option_name, '油醋汁' AS option_value, 1 AS is_default
  UNION ALL SELECT 'sauce', '千岛酱', 0
  UNION ALL SELECT 'sauce', '不加酱', 0
) m JOIN dishes d ON d.name = '沙拉';


-- ============================================================
-- 五、用户与画像（值由项目负责人 2026-10-14 提供）
-- ============================================================

-- 5.1 用户：1 行
INSERT INTO users (username) VALUES ('Axuan');

-- 5.2 用户画像：1 行
--     user_id 用子查询取上面那行的 id，不写死数字（写死一旦自增错位就连错人）
--     budget / mood / meal_period / age_range / gender 按负责人要求留 NULL
INSERT INTO user_profiles
  (user_id, hometown, current_city, budget, mood, headcount, portion_size, meal_period, age_range, gender)
SELECT id, '西安', '西安', NULL, NULL, 1, '中', NULL, NULL, NULL
FROM users WHERE username = 'Axuan';

-- 5.3 user_preference_tags / dining_companions / companion_avoid_tags
--     本次一行都不插（负责人未给值）。将来要初始化再单独补，不影响上面两行。



-- ============================================================
-- 六、入库后的核对语句（第六节 6 条证据，可直接复制去跑）
--   SELECT COUNT(*) FROM dishes;                 -- 期望 12
--   SELECT COUNT(*) FROM tags;                   -- 46（终值，2026-10-16 已核对）
--   SELECT COUNT(*) FROM dish_options;           -- 期望 33
--   SELECT d.name FROM dishes d
--     LEFT JOIN dish_tags dt ON dt.dish_id = d.id
--     LEFT JOIN tags t ON t.id = dt.tag_id AND t.category = 'meal'
--     WHERE t.id IS NULL;                        -- 期望 0 行
--   SELECT name FROM dishes;                     -- 中文不乱码
--   SELECT * FROM dish_options
--     WHERE dish_id = (SELECT id FROM dishes WHERE name = '麻辣烫');
--
-- 附加核对（第五节新增，不算在 6 条里）：
--   SELECT COUNT(*) FROM users;                  -- 期望 1
--   SELECT COUNT(*) FROM user_profiles;          -- 期望 1
--   SELECT u.username, p.hometown, p.portion_size -- 期望 Axuan / 西安 / 中
--     FROM users u JOIN user_profiles p ON p.user_id = u.id;
-- ============================================================
