# VISUAL WORLD PLAN

## 2026-10-02 — принято: гибридный город

- [x] Шесть расовых бухт на основе связной горной гряды, шесть малых портов,
  два природных препятствия; отдельные GLB и воспроизводимый Blender-экспорт.
- [x] Общий манифест береговой геометрии и твердых причалов, сохраненные якоря.
- [x] Шесть полных панорам чужих городов; пустой фон своей базы; отдельные
  расовые спрайты восьми зданий, пристроек, башен и строительных лесов.
- [x] Швартовка → экран города; фактические уровни/проекты определяют слои;
  действия используют существующие системы; выход → 3D-море.
- [x] Общая модель волн для воды и плавучести всех отображаемых судов.
- [ ] Художественная приемка владельцем готовых городов и подходов с моря.
- [ ] Профилирование FPS/памяти на целевой машине; отдельные арты каждой
  ступени уровня (сейчас три модульных визуальных этапа).

## Игровой флот и интерфейсы — 2026-10-01

Все 13 судов получили отдельные Blender/GLB и портреты PNG. Модели выбираются по сохранённому ID; расовые цвета и гербы, покачивание и тёплые фонари работают в игре. Общая морская тема объединяет окна; HUD показывает приборы корпуса, топлива и трюма. Карточки флота/верфи используют портреты моделей. Исправлен масштаб ПК; окна прокручиваются, карточки кристаллов адаптируются по ширине. Просмотр без записи сохранений: `scenes/showcase/ship_showcase.tscn`. Структура: `assets/world/ships/README.md`.

- [x] 5 обычных и 8 премиальных корпусов; источники и экспорт разложены отдельно.
- [x] Игровой HUD, единая тема, гербы и кнопки закрытия, изображения кораблей.
- [x] Широкий и вертикальный режим, просмотр флота с выбором расы/ночи.
- [ ] Следующий художественный проход: расовая геометрия корпусов и парусов, орнаменты, тонкие материалы и волны. Цвета и гербы пока не заменяют уникальный корпус для каждой расы.
- [ ] Замеры FPS/памяти на реальном Android-устройстве.


## Home-base geometry and racial architecture — 2026-10-01

Owner references are stored in `assets/references/home_base/`. The first modular 3D base is integrated: a sheltered bay with shoals, pale beaches, green cliffs, terraces, stairs, separate 1–30-level models for every catalogued building, and the two universal crystal towers. Its Godot showcase exposes maximum construction, level comparison, all six factions, and day/night; gameplay uses only saved construction levels.

Faction architecture now uses distinct roof silhouette kits plus the existing faction palettes: tidal fins, forge pinnacles, trade-house cupolas, sky-clan wings/spires, deep-stone crystal crowns, and human harbor lookouts. The canonical emblems appear on animated flags at buildings, towers and the starter sloop. Small amber lanterns provide restrained night lighting. Models and Blender sources are modular; the catalog paths and positions remain replaceable.

This is the first complete geometry pass. The faceted rocks, material detail, foliage, foam and terrain transitions still need refinement toward the supplied painted references. Android performance has not yet been measured; desktop imports, tests and rendering are verified. See PROJECT_MAP for the next visual tasks.

## Owner-approved art direction — 2026-09-27

Sea Trader is a cinematic fantasy maritime world: a working trade-and-exploration game with the scale and wonder of a fantasy film. The sea is beautiful, immense, and occasionally strange; warfare is not the world's defining identity.

As of 2026-09-30, *Avatar: The Way of Water* is the direct art-direction reference for the Sea Trader environment. Earlier Atlantean and *The Lord of the Rings* references inform only maritime myth, scale, and monumentality. Do not reproduce any franchise's characters, locations, symbols, or signature designs; Sea Trader keeps original forms and worldbuilding.

Use stylized realism: readable ship silhouettes, believable coastlines and scale, expressive lighting, and imaginative color. Art must remain legible on a phone and perform on mobile hardware.


## Owner-locked visual style — 2026-09-30 (mandatory)

This is the project's visual rule for **all** future graphics. Do not drift from it when adding a menu, scene, model, portrait, icon, effect, or promotional/gameplay asset. If an asset does not fit these references, redesign it to fit before adding it.

- **Environment:** use the cinematic ocean world of *Avatar: The Way of Water* as the direct reference: clear turquoise shallows and lagoons, deep saturated blues, lush tropical shores, tall green cliffs, reefs, layered underwater light, and restrained bioluminescence at night. Build original Sea Trader islands, ports, skies, and landmarks.
- **Player heroes and troops:** every hero has an open, visible face; do not use face-covering masks or closed helmets. The player's primary silhouette is advanced, fitted future armor and functional futuristic weapons, with ancient geometry in trim, heraldry and engraved motifs. Add luminous cyan runes and restrained brass details. Characters look like a trained, equipped civilization — never ragged or primitive. Keep the mixed illustrated-realism finish of `assets/characters/infantry_guardian.jpg` and `assets/characters/infantry_scout.jpg`; these remain the face/material anchors. New troop types need distinct faces and silhouettes, not one portrait reused across all rows.
- **Ships, buildings, props, creatures, and other objects:** keep believable silhouettes and materials with the same painterly, cinematic finish and ocean palette. Their detailing should feel handcrafted and maritime; do not mix in unrelated cartoon, anime, flat-vector, or hyper-real asset styles.
- **Interface and icons:** make menus feel part of the same sea world: dark deep-sea panels, clear turquoise/cyan interaction accents, restrained brass/gold highlights, consistent illustrated card icons, and legible high-contrast text. PC/Steam layouts should use the available screen area and avoid scrollbars; arrange content to fit without cutting controls or labels.
- **Effects and lighting:** water, wakes, spray, clouds, sunrise/sunset, underwater rays, and night glow follow the same cinematic color and material language. Keep effects readable and performance-scalable; glow must not overwhelm navigation or text.
- **Consistency gate:** review every new or replaced visual asset against the environment reference, both character portraits, and the interface palette. Do not introduce another visual direction without the owner's explicit approval.

## Шесть рас мира Sea Trader — 2026-09-30

Мир населяют шесть торговых народов: пять фантастических рас — Нериды Прилива, Сурры Огня, Меридиане торговых домов, Аэры небесных кланов и Кристари Глубинного Камня — и люди Вольных портов. У пяти фантастических рас различаются тела, лица, пропорции и способы носить снаряжение; люди сохраняют человеческую анатомию и лица. Для них подготовлены поясные портреты-якоря 512×512 в `assets/characters/factions/`, а для всех шести народов — полнофигурные арты капитанов в `assets/characters/captains/`. Каждый народ торгует и защищает собственные гавани. Рейд на порт не превращает весь народ в вечного врага. Названия, экономика, роль в защите и требования к оригинальному дизайну описаны в `ideas/combat/PORT_RAIDS.md`.

## Расовые гербы и выбор игрока — 2026-09-30

В начале новой игры игрок выбирает один из шести народов мира. Выбранная раса задаёт постоянную визуальную принадлежность игрока и один закреплённый герб; он используется на базе, кораблях, форме войск, карточках гарнизона, карте и игровых сообщениях. Выбор не закрывает торговлю или дипломатические контакты с другими расами. Любые различия стартовых бонусов должны быть небольшими и понятными, чтобы выбор по внешности и истории не превращался в обязательный выбор «лучшей» расы.

Перед первой игрой показывается галерея шести капитанов в полный рост с гербом над каждым. Наведение мягко увеличивает карточку; клик открывает досье с описанием, игровым фокусом, преимуществом и слабой стороной. До подтверждения отдельно предупреждаем, что сменить расу в текущем сохранении будет нельзя; в досье доступны «Назад» и «Выбрать». Тексты уже задают направления народов, но числовые расовые модификаторы пока не подключены к экономике и бою.

У каждого из шести народов есть свой единственный неизменный герб с узнаваемым силуэтом и своей палитрой. Гербы и нейтральный знак Sea Trader лежат в `assets/ui/emblems/`; исходные векторные SVG сохраняются рядом, а герб людей в игре загружается из PNG для совместимости с импортом Godot. Эти постоянные знаки повторно используются в UI и игровых изображениях. Для нейтральных экранов используются знак Sea Trader или морские пиктограммы; случайные логотипы рас и флотов не добавляются. В боевом отчёте могут одновременно показываться только герб игрока и герб конкретного защищающегося порта. Гербы NPC-портов подключаются, когда портам будут назначены расы.

Карточка гильдии магов использует отдельную сине-бирюзовую палитру, кристаллическую геометрию и латунные детали (`assets/ui/cards/mage_guild.svg`); эффекты кристаллов атаки, брони и удачи должны оставаться различимы цветом и знаком, без визуального символа скорости.

## Визуальный стандарт для рейдов — 2026-09-30

Боевые отчёты остаются частью общей морской стилистики: тёмно-синие карточки, бирюзовые руны, латунная окантовка, выразительная иллюстрация победы или поражения. Отчёт делится на две равные стороны с отдельными карточками отрядов, артиллерии, потерь и ресурсов. На телефоне две стороны складываются вертикально; на ПК остаются рядом.

Игрок носит технологичную, плотно скроенную броню и футуристичное оружие с древними морскими мотивами в орнаменте; все лица открыты. Защитники — представители шести народов с собственными лицами, физиологией, силуэтами, бронёй, материалами и культурой; пять фантастических рас визуально отличны от людей, а не повторные портреты игрока в новых цветах. Осадные орудия изображаются отдельными оригинальными объектами техники. Победная и проигрышная иллюстрации следуют морскому миру и технологичному древнему-футуристическому направлению. В проекте сохранён 1280×720 концепт окна итогов `assets/ui/concepts/port_raid_result_refined_pc_1280x720.jpg`; это визуальная опора, не готовый runtime UI.

## Current implementation and source of truth

Trade, navigation, routes, contracts, crews, ports, and economy remain driven by the saved deterministic world and game systems. The shared 3D renderer presents that same world; visual effects and imported models must not alter game state.

Detailed art can be added in stages after each gameplay slice is stable. Procedural placeholders remain useful during mechanics development.

## Camera and readability

The final world has three presentation modes:

- **Strategic / Map** — routes, known ports, navigation, and world orientation.
- **Dynamic / Auto** — a smooth camera arc between overview and sailing views.
- **Sailing / Close** — the ship, horizon, nearby coastline, and water motion remain readable at sea.

The player can select an explicit overview or close view. In close view, desktop right-mouse drag orbits around the ship; mobile uses a dedicated touch gesture. Zoom controls distance and does not unexpectedly remove all horizon and motion cues while sailing in open water. Near a coast, the camera can lower smoothly to show the ship against the land.

Keep ship heading, speed, wake, and a clear navigation reference available without covering the scene. Camera movement must not imply that the ship has stopped.

## World geography and landmarks

The world should feel broader than a field of small, evenly spaced islands. Generate deterministic regions containing a mix of:

- broad continental shorelines and very large islands that take time to sail around;
- open-water crossings, island chains, deep bays, fjords, narrow straits, and navigable passages between cliffs;
- smaller islands and reefs that make coastlines varied without filling every sea lane;
- a small number of fantastical floating islands suspended in cloud, used as rare distant landmarks and special regional set pieces;
- discoverable hazards and unusual waters, used to create route choices rather than constant combat.

Procedural generation should use a seeded regional layout and coastline templates so continents, straits, and archipelagos have a coherent shape and remain stable after saving. Ports belong at plausible sheltered coves or inlets, not at every coastline point.

## Ports and monumental structures

Most ports should be useful, distinct working harbors. A few rare hubs may be monumental: vast sea gates, terraced quays, ancient coastal cities, or citadel-like harbor walls. Port scale and architecture should signal a region's history and importance.

A signature exploration moment is sailing from open water into a hidden, sheltered bay: the coastline opens gradually to reveal towering cliffs, lush slopes, waterfalls, reefs, cloud-wrapped heights, and an ancient harbor. Some island approaches can pass between giant carved statues into an inner bay or city. The statues and approach should be navigable landmarks, not decoration that blocks the route. Atlantean-inspired cities should feel ancient and maritime while retaining an original Sea Trader design.

The home port should read clearly as the player's base. Rare grand ports should feel exceptional because ordinary harbors leave room for contrast.

## Day, night, stars, and luminous water

Daylight is the default for readable sailing and must last substantially longer than night. Use a configurable 3:1 day-to-night ratio as the first tuning target; keep twilight transitions short enough to preserve the brief night-sky moment without making routine navigation difficult.

Sunrise and sunset must read as gradual lighting events, not instant palette swaps. As the Sun approaches and crosses the horizon, change the sky gradient, ambient light, cloud color, coast silhouettes, and reflected color on the sea together. Use a bright horizon glow with warm gold, orange, and rose tones, then fade toward the cooler upper sky. Atmospheric scattering is strongest visually at low Sun angles; keep the transition smooth and restrained rather than adding constant lens flare.

The current star field and constellation treatment are accepted by the owner (2026-10-06). Keep the existing look; matching a real hemisphere, astronomical coordinates, calendar, or ship position is not a requirement. Revisit the starfield only if the owner asks for a change.

At night, add restrained bioluminescent or fluorescent-looking light around the hull and in the wake. It should reveal the ship and nearby water without turning the whole sea into glowing neon. Ship lamps, moonlight, stars, and coast silhouettes should preserve enough contrast to steer safely.

## Owner direction — daylight cycle and accepted star field — 2026-10-06

The current star field is accepted. Do not add a real-world astronomy or coordinate-matching task unless the owner requests it.

The sunrise and sunset should visibly carry the transition: changing atmospheric color and light, a luminous horizon, and matching reflections on the sea. Day should be much longer than night. Begin playtesting with a 3:1 ratio, then tune the cycle while preserving a short, memorable interval for stargazing.

## Mobile performance and asset workflow

Stream and level-of-detail the world: distant coastlines can use simplified silhouettes; nearby islands and ports receive detailed meshes and props. Keep water shader cost, transparent effects, lights, and floating-island geometry within a measured mobile budget. Provide scalable effect quality where needed.

The world uses reusable, modular 3D scenes so new islands, ports, statues, and sea objects can be added to the asset catalog without changing trading or save logic. The player can model ships and large props in SketchUp. Preferred import format for Godot is **GLB**. First-pass ship models should be centered, share an agreed forward axis, and use consistent scale.

Ship tiers need distinct silhouettes: small boat, barque, schooner, freighter, and tanker. All visual assets remain a presentation layer over the same game systems.


## Owner direction — environment and hero art — 2026-09-30

The owner has now selected *Avatar: The Way of Water* as the direct visual reference for the **environment**. Use its cinematic ocean-world qualities: luminous turquoise shallows and lagoons, saturated blue depths, tropical coastlines, lush cliffs and vegetation, layered underwater light, reefs, and restrained bioluminescence at night. The Sea Trader world must keep original coastlines, ports, ships, symbols, and landmark designs; use the film as an art-direction reference, not as a source for copied assets or locations.

The **heroes and troops** use the mixed illustrated-realism finish of the existing repository portraits: `assets/characters/infantry_guardian.jpg` and `assets/characters/infantry_scout.jpg` are references for face rendering, painterly detail, and material treatment only. Their old clothing is not the equipment target. Player soldiers must wear fitted, advanced future armor with open faces, readable ancient geometry in the trim, cyan runes, restrained brass, and functional futuristic weapons. They should look supplied, trained, and technologically capable — never dressed in rags or primitive kit.

## Implemented visual foundation — 2026-09-27

The shared 3D renderer now supports the first sailing-view slice:

- Shore proximity and close zoom blend the overhead view into the same 3D sea; desktop right-drag and mobile two-finger gestures orbit, while the pinch gesture also controls zoom.
- The close view updates over open water, so it does not depend on a nearby island.
- The first day/night pass uses a five-minute cycle with a target 3:1 daylight-to-night ratio. A procedural gradient sky, animated solar elevation, warm sunrise/sunset lighting, coordinated ambient light, and a restrained warm tint on the water establish dawn and dusk.
- The night sky uses about 6,300 seed-stable procedural star points scattered across the whole dome, plus the existing zodiac and constellation marks. The Milky Way band was removed after visual review because its edge made the sky dome's rendering limit noticeable. The current star field and constellations are accepted by the owner; exact astronomical positioning is out of scope.
- Procedural island surfaces use seed-stable irregular coastlines with a visual opening at a harbor. Rare large islands receive a floating landmark; the home harbor receives a pair of gate statues.
- These meshes are visual only. Navigation, collisions, world seed, and save data continue to use the existing generated-world data.

The star silhouettes are a visual prototype. Once the world calendar and latitude are defined, replace them with an accurately oriented star field. Region-scale continental generation, bespoke coast/port meshes, waterfall effects, and mobile graphics presets remain future implementation slices.

## Реалистичное небо и каюта капитана — 2 октября 2026
В игровом 3D-виде используется процедурный слой дневных облаков в половинном разрешении sky shader. Облачность плавно исчезает при переходе к ночи и не закрывает звёздное небо. Слой построен на лёгком процедурном шуме, совместимом с текущим мобильным рендерером; профилирование на реальных мобильных GPU ещё требуется.
Кабинет капитана уплотнён: сведения и карьера располагаются слева, иллюстрация каюты — справа. Для каждой из шести рас создан отдельный вариант в исходном образе выбранного капитана; лицо, раса и костюм остаются неизменными, меняются поза и обстановка. Арты хранятся отдельно в `assets/characters/captains/*_captain_cabin.png`.
Верхние и всплывающие окна используют палитру и форму рамки выбранной расы через общую игровую тему. Ночные фонари уже подключены к общему циклу для судна игрока и 3D-моделей морского трафика.

## Величественная гавань и небесный порт — 1 октября 2026
База перестроена в город с широкой подковообразной бухтой: шесть причалов, кварталы, рабочие, зелёные скалы, рифы и один морской вход. Восемь основных зданий имеют самостоятельные модели всех 30 уровней; архитектура кварталов и гербы соответствуют выбранной расе. В режиме игры отображаются сохранённые уровни; просмотр базы показывает максимальную застройку.
Навигация использует общий контур берега и рифов: торговцы и флот обходят сушу, прибывающие корабли используют разные модели и не мельче корабля игрока. Портовая точка и сохранённая экономика не переносятся; пространственная компоновка применяется как представление мира.
Два маяка включают вращающиеся прожекторы ночью. Над городом добавлены пять парящих островов с растительностью, домами, расовыми флагами, облаками, подвесными мостами, причалами и двумя спускающимися верёвочными лестницами. Небесная гавань пока визуальная: отдельная механика воздушной торговли в планах. Чайки сидят на причалах, кружат у бухты и периодически появляются рядом с игроком в плавании.
Следующие этапы: профилирование полного города на мобильных устройствах, художественная доработка материалов и облаков, отдельные механики небесных причалов.

## Ревизия графики и интерфейса после просмотра владельцем
Убраны капсулы толпы; полноценные жители требуют отдельных моделей и анимации. Наземные скалы сглажены, кроны получили гладкие нормали, порт дополнен лавками, товарами, бочками с обручами, ящиками со скобами, канатами, керамикой, навесами и швартовными тумбами. Деревянные причалы опущены до 0.42 м; отдельные причальные здания также опущены, масштабы основных зданий уменьшены до более согласованных с кораблями и жилыми кварталами. Максимальная застройка теперь включает 16 кварталов.
Материалы дерева, кладки, скал, штукатурки, кровли, растительности и ткани используют отдельные 1024px текстуры и карты нормалей из assets/world/materials/textures/. Включено сглаживание 4x MSAA для 3D. Дальнейшая художественная задача: детализированные растения, скульпт парящих скал и полноценные жители.
Интерфейс по умолчанию оставляет море открытым: показатели и раскрываемые разделы находятся в верхней полосе. Порт, корабельные приборы и подсказки раскрываются по нажатию; первый заказ больше не открывается автоматически. Прибывающие торговцы сохраняют запас между корпусами, начинают рейсы с интервалами и проходят канал по очереди; дублирующийся корпус торговца удалён.

## Детальная тропическая версия — 1 октября 2026
Сплошные кроны заменены изогнутыми текстурированными листьями: около 19 тысяч листовых веток на наземном острове, отдельная растительность парящих островов и жилых кварталов. Пальмы получили изогнутые детальные листья. Листва колышется через tropical_leaf.gdshader. Материалы скал, кладки, дерева и мшистого грунта заменены игровыми текстурами; дерево и камень имеют согласованные карты нормалей. Mipmaps и анизотропная фильтрация устраняют рябь вдали.
В assets/world/buildings/details/ добавлены шесть самостоятельных комплектов архитектурной отделки с Blender-источниками: арочные входы, оконные рамы и ставни, балконы, карнизы, объёмная черепица и колоннада гильдии. Отделка адаптируется к уровню здания и сохраняет расовые крыши, палитры и гербы. Максимальная Blender-сцена обновлена с островами, кораблями, деталями и упакованными текстурами.
Деревянные причалы опущены до 0.24 м, причальные здания — до подходящего уровня палуб. Проверки логики и запуска прошли в изолированной копии; дневной и ночной рендер проверен на Windows в Godot 4.7.2 Compatibility. Художественная доработка остаётся процессом по скриншотам владельца; текущая версия не объявляется финальным качеством Steam-релиза.

## Образцы 2/3 и зелёные острова — 2 октября 2026
- Принято направление 2.jpg/3.jpg: стилизованная зелень и слоистые скалы;
  4.jpg/5.jpg используются для тонких линий причалов и предметных деталей.
- Сделано: кривые Безье для стволов, удаление наружных корней, объёмные кроны,
  закрытые подводные основания семи скал, пять горных троп, дорожки кварталов,
  вспомогательные сараи/рыбацкие сушилки, три зелёных острова на маршрутах.
- Источники модульные; runtime-экспорт объединяет геометрию по материалам.
  Валидатор проверяет отсутствие корней, замкнутость скал, подводный низ,
  наличие троп и границы маршрутных островов.
- Далее: разнообразить силуэты зелёных массивов, внедрить новый ландшафт в
  портовые острова с согласованием бухт/коллизий, добавить площадки отдыха
  на тропах, полноценные модели/анимации жителей. Измерение VRAM ещё не проведено.

## Окна, кабинет капитана и океан — 2 октября 2026
- Кабинет: арт каюты заполняет окно; сведения находятся в прокручиваемой левой
  панели; кнопка закрытия закреплена справа сверху. Оригинальные лица и одежда
  капитанов не меняются.
- Все окна и портовые панели получают декоративную расовую ткань-флаг сверху.
  Кнопки используют расовые цвета, рамки и состояния наведения/нажатия; базовый
  размер шрифта уменьшен. Полоса ресурсов находится в отдельной верхней строке
  справа от кнопок и игнорирует клики.
- Океан: плотность сетки увеличена вдвое, усилены гребешки и береговая пена.
  У портов добавлены светлые песочные мелководные отмели под водной поверхностью.
  Отмели пока декоративные и не влияют на навигацию.
- Проверено: Godot 4.7.2, 1669 unit и 174 smoke проверки. Следом — визуальная
  оценка в игровом окне на разных разрешениях и настройка цвета/пены по кадрам.
- Единый интерфейсный мотив уточнён по карточкам капитанов из `Downloads/vid`:
  тёмно-синие поверхности, двойная тонкая латунная рамка, угловые завитки,
  бирюзовые детали и кнопки с теми же фасками. Применяется ко всем контролам;
  окно кабинета имеет безопасный внутренний отступ рамки и закреплённые кнопки.
- GLB острова, предоставленный автором, удалён из каталога ресурсов; старые
  сохранённые метки очищаются. Береговые препятствия остаются процедурными.
- Кнопки меню теперь используют вырезанный фон «Обзор» из `premium-fleet-catalog.png`
  с очищенным центром для динамической подписи, а не рисованную SVG-имитацию.
  В кабинете удалены верхний флаг/логотип и внешняя рамка поверх изображения.
- Небесная гавань перенесена в отдельную точку примерно в 600 м от домашней
  бухты. Из её GLB удалено 800 полигонов водопадов; добавлена проверка материалов.
- Океан: амплитуда волн снижена до ~0.18 м пика, глубина читается линейной
  фильтрацией вместо клетчатой выборки; гребневая пена стала тоньше и менее блочной.

## Утверждённый интерфейс — 2 октября 2026
- [x] Перенесена графика из `main_hud_concept_v1.png`: латунные рамки,
  фон карты, отдельные иконки меню и ресурсов. Подписи и числа динамические.
  Исходники нарезки и инструкция: `assets/ui/styles/approved_hud/README.md`.
- [x] Верхнее меню: Карта, Порт, Флот, Капитан, Задания; дополнительные
  разделы доступны через ⋮. При недостатке ширины ресурсы занимают второй ряд.
- [x] Дополнительные складские товары появляются автоматически в «Ещё +N»
  по каталогу и текущим запасам. Окна располагаются под фактической высотой HUD.
- [x] Реальные кадры Godot проверены в 1920×1080, 1280×720 и 720×960.
  Исправлены размер карты и привязка прокручиваемого текста кабинета к окну.
  Кадры воспроизводятся локальной сценой предпросмотра в игнорируемую папку `outputs/`; проверки запуска и окон проходят.
- [ ] Острова по утверждённому арту: сначала сопоставить силуэт из игровой камеры
  (вертикальные скальные массивы, большая бухта, уступы и террасы), затем детали,
  растительность и материалы; отдельно согласовать береговые коллизии.
  Текущие процедурные острова не соответствуют качеству и формам концепта.
- [x] Создан отдельный Blender-образец `assets/world/islands/karst_cove/source/karst_cove.blend`.
  По замечанию владельца отдельные вытянутые скалы заменены связной грядой
  с седловинами и боковыми отрогами; материалы и растительность доступны в сцене.
- [ ] Игровой экспорт принятой гряды, упрощённые коллизии и проверка маршрутов у бухты.
- [x] Форма гряды принята владельцем. В `karst_cove_city.blend` добавлены
  небольшие дома людского стиля, портовые здания, торговые навесы, причалы и
  флаги с закреплённым гербом. Высота домов примерно 7–8 м, портового офиса — до 10 м.
- [x] По указанию владельца весь видимый лес городской сцены заменён low-poly:
  250 треугольников на дерево, семь общих мешей, один материал с цветами вершин.
  Подготовлены более простые варианты деревьев и рельефа для расстояния.
- [ ] Подключить эти LOD и пространственные группы инстансов в Godot;
  замерить FPS и память. Счётчики геометрии не считаются проверкой быстродействия.

## Обновление 2026-10-03
- [x] Шесть торговцев с отдельными лицами и расовой одеждой; торговец справа, управление слева.
- [x] Крупные расовые изображения зданий справа, параметры и материалы слева.
- [x] Осмотр реальных моделей всего каталога кораблей с вращением и приближением.
- [x] Военные транспорты 60 бойцов / 6 орудий, погрузка из гарнизона, сопровождение и потери погруженных войск.
- [x] Тестовый «Авангард» в сохранении владельца; резервная копия прогресса.
- [ ] Продолжительное ручное плавание большой эскадрой, баланс ремонта транспортов и производительность на целевом ПК.
### 2026-10-03 — battle and personnel presentation
- [x] Build six separate unit portraits in Sea Trader techno-fantasy style; no historical military costumes.
- [x] Build full-screen raid, tribute handover, and emergency rebellion backgrounds.
- [x] Show combat participants and casualties through reusable unit cards.
- [x] Add distinct race portraits to the hire board and visible random strengths/flaws.
- [ ] Expand the staff roster to race-specific names and more portraits as roles grow.
- [ ] Consider a real ship provisions stock and ration depletion loop; current food remains a voyage cash expense for stable operation.
