#!/usr/bin/env python3
"""
Generate App Store metadata for Voice Journal in 20 locales.
Run: python3 fastlane/generate_metadata.py
"""
import os

BASE = os.path.join(os.path.dirname(__file__), "metadata")

# ---------------------------------------------------------------------------
# English (en-US) — base content
# ---------------------------------------------------------------------------

EN_DESC = """\
Voice Journal turns your spoken thoughts into a private, searchable diary — no typing, no formatting needed.

Press once and speak freely. Every word is transcribed right on your device using on-device AI — no internet connection required. The moment you finish speaking, your thoughts become searchable text.

── PRIVATE BY DESIGN ──
Nothing ever leaves your phone. No account to create, no cloud storage, no one else who can read your entries. Just you and your thoughts.

── REFLECT ON YOUR PATTERNS ──
Each entry gets a quiet AI summary, a mood tag, and recurring themes. Over time you'll see exactly what your mind returns to most.

── DAILY PROMPTS ──
Every day brings a fresh reflection prompt and a small moment of motivation — just enough to get the first word out.

── BUILT FOR HOW YOU THINK ──
• Tap once to record — no setup, no friction
• On-device transcription, fully offline
• Calendar to browse your history
• Instant search across every entry
• Favorites for the moments that matter
• Siri Shortcuts to record from anywhere
• Beautiful light and dark mode

Voice Journal is for anyone who thinks better when they talk — therapists, writers, parents, students, or anyone who needs a quiet place to think out loud.

Start your first entry today.\
"""

# ---------------------------------------------------------------------------
# All locale data
# Format: name (≤30), subtitle (≤30), keywords (≤100), description, release_notes
# ---------------------------------------------------------------------------

LOCALES = {

"en-US": {
    "name": "Voice Journal – AI Voice Diary",
    "subtitle": "Voice diary & mood journal app",
    "keywords": "voice diary,daily journal,mood tracker,reflection,voice notes,private journal,mindfulness,gratitude",
    "description": EN_DESC,
    "release_notes": "Bug fixes and performance improvements.",
},

"de-DE": {
    "name": "Voice Journal – Sprachtagebuch",
    "subtitle": "Privates KI-Tagebuch, offline",
    "keywords": "Tagebuch,Sprachtagebuch,Stimmung,Reflexion,Selbstreflexion,Wohlbefinden,Transkription,Notizbuch",
    "description": """\
Voice Journal verwandelt deine gesprochenen Gedanken in ein privates, durchsuchbares Tagebuch – ganz ohne Tippen.

Einmal drücken, frei sprechen. Jedes Wort wird direkt auf deinem Gerät transkribiert – keine Internetverbindung erforderlich. Sobald du fertig bist, sind deine Gedanken als durchsuchbarer Text gespeichert.

── PRIVAT VON ANFANG AN ──
Nichts verlässt dein Gerät. Kein Konto, keine Cloud, kein Fremdzugriff. Nur du und deine Gedanken.

── ERKENNE DEINE MUSTER ──
Jeder Eintrag erhält eine KI-Zusammenfassung, einen Stimmungs-Tag und wiederkehrende Themen. Mit der Zeit erkennst du, was dich wirklich beschäftigt.

── TÄGLICHE IMPULSE ──
Jeden Tag wartet ein frischer Reflexionsimpuls auf dich – gerade genug, um loszulegen.

── ENTWICKELT FÜR DEINE GEDANKEN ──
• Einmal tippen, sofort aufnehmen
• Transkription komplett offline
• Kalender zur Übersicht deiner Einträge
• Sofortsuche über alle Einträge
• Favoriten für besondere Momente
• Siri-Kurzbefehle für unterwegs
• Helles und dunkles Design

Für alle, die beim Reden besser denken – Therapeuten, Schreibende, Eltern, Studierende oder Menschen, die einen ruhigen Ort zum Nachdenken brauchen.

Starte heute deinen ersten Eintrag.\
""",
    "release_notes": "Fehlerbehebungen und Leistungsverbesserungen.",
},

"fr-FR": {
    "name": "Voice Journal – Journal Vocal",
    "subtitle": "Journal intime vocal avec IA",
    "keywords": "journal vocal,journal intime,humeur,réflexion,transcription,vie privée,pleine conscience,gratitude",
    "description": """\
Voice Journal transforme vos pensées vocales en un journal intime privé et consultable — sans saisie au clavier.

Appuyez une fois et parlez librement. Chaque mot est transcrit directement sur votre appareil par une IA locale — aucune connexion internet requise. Dès que vous avez fini de parler, vos pensées deviennent un texte consultable.

── PRIVÉ PAR CONCEPTION ──
Rien ne quitte jamais votre téléphone. Pas de compte à créer, pas de cloud, personne d'autre ne peut lire vos entrées. Juste vous et vos pensées.

── DÉCOUVREZ VOS SCHÉMAS ──
Chaque entrée reçoit un résumé IA discret, une étiquette d'humeur et des thèmes récurrents. Au fil du temps, vous verrez ce qui occupe vraiment votre esprit.

── INVITATION QUOTIDIENNE ──
Chaque jour apporte une nouvelle invitation à la réflexion et une petite dose de motivation — juste ce qu'il faut pour commencer.

── CONÇU POUR VOTRE FAÇON DE PENSER ──
• Enregistrement en un seul toucher
• Transcription entièrement hors ligne
• Calendrier pour parcourir votre historique
• Recherche instantanée dans toutes les entrées
• Favoris pour les moments importants
• Raccourcis Siri pour enregistrer partout
• Mode clair et sombre

Voice Journal est pour tous ceux qui pensent mieux en parlant — thérapeutes, écrivains, parents, étudiants ou quiconque a besoin d'un espace calme pour réfléchir à voix haute.

Commencez votre première entrée aujourd'hui.\
""",
    "release_notes": "Corrections de bugs et améliorations des performances.",
},

"es-ES": {
    "name": "Voice Journal – Diario de Voz",
    "subtitle": "Diario vocal privado con IA",
    "keywords": "diario de voz,diario personal,humor,reflexión,transcripción,privacidad,mindfulness,gratitud",
    "description": """\
Voice Journal convierte tus pensamientos hablados en un diario privado y con búsqueda — sin necesidad de escribir.

Pulsa una vez y habla libremente. Cada palabra se transcribe en tu dispositivo mediante IA local — sin conexión a internet. En cuanto terminas de hablar, tus pensamientos se convierten en texto buscable.

── PRIVACIDAD POR DISEÑO ──
Nada abandona tu teléfono. Sin cuenta que crear, sin almacenamiento en la nube, nadie más puede leer tus entradas. Solo tú y tus pensamientos.

── DESCUBRE TUS PATRONES ──
Cada entrada recibe un resumen de IA, una etiqueta de estado de ánimo y temas recurrentes. Con el tiempo verás qué ocupa realmente tu mente.

── PROPUESTA DIARIA ──
Cada día trae una nueva propuesta de reflexión y una pequeña dosis de motivación — lo justo para comenzar.

── DISEÑADO PARA TU FORMA DE PENSAR ──
• Graba con un solo toque
• Transcripción completamente sin conexión
• Calendario para explorar tu historial
• Búsqueda instantánea en todas las entradas
• Favoritos para los momentos importantes
• Atajos de Siri para grabar desde cualquier lugar
• Modo claro y oscuro

Voice Journal es para quienes piensan mejor cuando hablan — terapeutas, escritores, padres, estudiantes o cualquiera que necesite un espacio tranquilo para pensar en voz alta.

Comienza tu primera entrada hoy.\
""",
    "release_notes": "Correcciones de errores y mejoras de rendimiento.",
},

"es-MX": {
    "name": "Voice Journal – Diario de Voz",
    "subtitle": "Diario vocal privado con IA",
    "keywords": "diario de voz,diario personal,humor,reflexión,transcripción,privacidad,mindfulness,gratitud",
    "description": """\
Voice Journal convierte tus pensamientos en un diario privado y con búsqueda — sin necesidad de escribir.

Toca una vez y habla con libertad. Cada palabra se transcribe en tu dispositivo mediante IA local — sin internet. Cuando terminas de hablar, tus pensamientos se convierten en texto que puedes buscar.

── PRIVACIDAD POR DISEÑO ──
Nada sale de tu teléfono. Sin cuenta, sin nube, nadie más puede leer tus entradas. Solo tú y tus pensamientos.

── DESCUBRE TUS PATRONES ──
Cada entrada recibe un resumen de IA, una etiqueta de estado de ánimo y temas frecuentes. Con el tiempo descubrirás qué ocupa más tu mente.

── PROPUESTA DIARIA ──
Cada día llega una nueva propuesta de reflexión y motivación — lo justo para empezar.

── HECHO PARA TU FORMA DE PENSAR ──
• Graba con un solo toque
• Transcripción sin conexión
• Calendario para explorar tu historial
• Búsqueda instantánea en todas las entradas
• Favoritos para los momentos que importan
• Atajos de Siri para grabar desde donde sea
• Modo claro y oscuro

Para quienes piensan mejor hablando — terapeutas, escritores, papás y mamás, estudiantes o cualquiera que necesite un espacio para pensar en voz alta.

Comienza tu primer entrada hoy.\
""",
    "release_notes": "Correcciones de errores y mejoras de rendimiento.",
},

"ja": {
    "name": "Voice Journal – 音声日記AI",
    "subtitle": "プライベート音声日記アプリ",
    "keywords": "音声日記,日記,気分記録,自己反省,文字起こし,プライバシー,マインドフルネス,ボイスメモ",
    "description": """\
Voice Journalは、話した言葉をそのままプライベートな日記に変換するアプリです。タイピング不要。

1回タップして、自由に話すだけ。デバイス上のAIがすべてを文字起こし — インターネット接続不要。話し終わった瞬間、思考が検索可能なテキストになります。

── 完全プライベート ──
データは一切外部に送られません。アカウント不要、クラウド不使用。あなたの日記は、あなただけのもの。

── 自分のパターンを見つける ──
各エントリにAIサマリー、気分タグ、繰り返し現れるテーマが付きます。時間をかけて、自分が何について考えがちかが見えてきます。

── 毎日のリフレクション ──
毎日、新しい振り返りのプロンプトと小さなモチベーションが届きます。

── あなたの思考に合わせた設計 ──
• ワンタップで録音開始
• 完全オフライン文字起こし
• カレンダーで過去の記録を閲覧
• 全エントリを即座に検索
• お気に入りで大切な瞬間を保存
• Siriショートカットでどこでも録音
• ライト・ダークモード対応

話すことで考えがまとまる方すべてに — カウンセラー、物書き、保護者、学生、または静かに思考を整理したい方。

今日、最初のエントリを始めましょう。\
""",
    "release_notes": "バグ修正とパフォーマンスの改善。",
},

"ko": {
    "name": "Voice Journal – AI 음성 일기",
    "subtitle": "프라이빗 음성 일기 앱",
    "keywords": "음성일기,일기,기분기록,자기반성,음성메모,개인정보보호,마음챙김,감사일기",
    "description": """\
Voice Journal은 말한 내용을 그대로 개인 일기로 변환해주는 앱입니다. 타이핑이 필요 없습니다.

한 번 탭하고 자유롭게 말하세요. 기기의 AI가 모든 단어를 바로 텍스트로 변환합니다 — 인터넷 연결 불필요. 말을 마치는 순간 생각이 검색 가능한 텍스트가 됩니다.

── 완전한 프라이버시 ──
데이터는 절대 외부로 전송되지 않습니다. 계정 불필요, 클라우드 없음. 오직 당신만의 일기.

── 나의 패턴 발견하기 ──
각 항목마다 AI 요약, 기분 태그, 반복 주제가 추가됩니다. 시간이 지나면서 자신이 무엇을 자주 생각하는지 알게 됩니다.

── 매일의 질문 ──
매일 새로운 성찰 질문과 작은 동기부여가 제공됩니다.

── 당신의 사고방식에 맞는 설계 ──
• 한 번 탭으로 녹음 시작
• 완전 오프라인 받아쓰기
• 달력으로 과거 기록 탐색
• 모든 항목 즉시 검색
• 소중한 순간을 즐겨찾기
• Siri 단축어로 어디서나 녹음
• 라이트·다크 모드 지원

말할 때 생각이 정리되는 모든 분께 — 상담사, 작가, 부모님, 학생, 혼자 조용히 생각을 정리하고 싶은 분.

오늘 첫 번째 항목을 시작해보세요.\
""",
    "release_notes": "버그 수정 및 성능 개선.",
},

"zh-Hans": {
    "name": "Voice Journal – AI语音日记",
    "subtitle": "私人语音日记，离线AI转写",
    "keywords": "语音日记,日记,情绪记录,自我反思,语音转文字,隐私,正念,感恩日记",
    "description": """\
Voice Journal 将您的语音想法转化为私密、可搜索的日记——无需打字，无需格式化。

轻触一次，自由说话。每个字都由设备端AI即时转写——无需网络连接。说完之后，您的想法立刻变成可搜索的文字。

── 隐私优先设计 ──
数据永远不会离开您的手机。无需创建账户，没有云存储，没有人能读取您的日记。只有您和您的思想。

── 发现您的规律 ──
每篇日记都会获得AI简洁摘要、情绪标签和反复出现的主题。随着时间推移，您会了解自己最常思考的是什么。

── 每日引导 ──
每天都有新的反思提示和一点动力——刚好足够开始第一句话。

── 专为您的思维方式而设计 ──
• 一键开始录音
• 完全离线的设备端转写
• 日历浏览过往记录
• 即时搜索所有日记
• 收藏重要时刻
• Siri快捷指令随时录音
• 支持浅色和深色模式

适合所有在说话时思路更清晰的人——治疗师、作家、父母、学生，或任何需要安静思考空间的人。

今天就开始您的第一篇日记。\
""",
    "release_notes": "修复错误并提升性能。",
},

"zh-Hant": {
    "name": "Voice Journal – AI語音日記",
    "subtitle": "私人語音日記，離線AI轉寫",
    "keywords": "語音日記,日記,情緒記錄,自我反思,語音轉文字,隱私,正念,感恩日記",
    "description": """\
Voice Journal 將您的語音想法轉化為私密、可搜尋的日記——無需打字，無需格式化。

輕觸一次，自由說話。每個字都由裝置端AI即時轉寫——無需網路連線。說完之後，您的想法立刻變成可搜尋的文字。

── 隱私優先設計 ──
資料永遠不會離開您的手機。無需建立帳號，沒有雲端儲存，沒有人能讀取您的日記。只有您和您的思想。

── 發現您的規律 ──
每篇日記都會獲得AI簡潔摘要、情緒標籤和反覆出現的主題。隨著時間推移，您會了解自己最常思考的是什麼。

── 每日引導 ──
每天都有新的反思提示和一點動力——剛好足夠開始第一句話。

── 專為您的思維方式而設計 ──
• 一鍵開始錄音
• 完全離線的裝置端轉寫
• 行事曆瀏覽過往記錄
• 即時搜尋所有日記
• 收藏重要時刻
• Siri捷徑隨時錄音
• 支援淺色和深色模式

適合所有在說話時思路更清晰的人——治療師、作家、父母、學生，或任何需要安靜思考空間的人。

今天就開始您的第一篇日記。\
""",
    "release_notes": "修復錯誤並提升效能。",
},

"pt-BR": {
    "name": "Voice Journal – Diário de Voz",
    "subtitle": "Diário vocal privado com IA",
    "keywords": "diário de voz,diário pessoal,humor,reflexão,transcrição,privacidade,mindfulness,gratidão",
    "description": """\
Voice Journal transforma seus pensamentos falados em um diário particular e pesquisável — sem precisar digitar nada.

Pressione uma vez e fale livremente. Cada palavra é transcrita diretamente no seu dispositivo por IA local — sem conexão à internet. Ao terminar de falar, seus pensamentos viram texto pesquisável.

── PRIVACIDADE POR DESIGN ──
Nada sai do seu telefone. Sem conta para criar, sem armazenamento em nuvem, ninguém mais pode ler suas entradas. Apenas você e seus pensamentos.

── DESCUBRA SEUS PADRÕES ──
Cada entrada recebe um resumo de IA, uma etiqueta de humor e temas recorrentes. Com o tempo, você verá o que sua mente mais revisita.

── PROPOSTA DIÁRIA ──
Todos os dias traz uma nova proposta de reflexão e um pequeno momento de motivação — o suficiente para começar.

── FEITO PARA SUA FORMA DE PENSAR ──
• Grave com um único toque
• Transcrição completamente offline
• Calendário para explorar seu histórico
• Busca instantânea em todas as entradas
• Favoritos para os momentos que importam
• Atalhos da Siri para gravar de qualquer lugar
• Modo claro e escuro

Voice Journal é para quem pensa melhor falando — terapeutas, escritores, pais, estudantes ou qualquer pessoa que precise de um espaço tranquilo para pensar em voz alta.

Comece sua primeira entrada hoje.\
""",
    "release_notes": "Correções de bugs e melhorias de desempenho.",
},

"it": {
    "name": "Voice Journal – Diario Vocale",
    "subtitle": "Diario vocale privato con IA",
    "keywords": "diario vocale,diario personale,umore,riflessione,trascrizione,privacy,mindfulness,gratitudine",
    "description": """\
Voice Journal trasforma i tuoi pensieri parlati in un diario privato e ricercabile — senza bisogno di digitare.

Premi una volta e parla liberamente. Ogni parola viene trascritta direttamente sul tuo dispositivo dall'IA locale — senza connessione internet. Non appena finisci di parlare, i tuoi pensieri diventano testo ricercabile.

── PRIVATO PER DESIGN ──
Nulla lascia mai il tuo telefono. Nessun account da creare, nessun cloud, nessun altro può leggere le tue voci. Solo tu e i tuoi pensieri.

── SCOPRI I TUOI SCHEMI ──
Ogni voce riceve un riassunto IA discreto, un'etichetta dell'umore e temi ricorrenti. Nel tempo vedrai cosa occupa davvero la tua mente.

── SPUNTO QUOTIDIANO ──
Ogni giorno arriva un nuovo spunto di riflessione e un piccolo momento di motivazione — giusto quel che serve per iniziare.

── PROGETTATO PER IL TUO MODO DI PENSARE ──
• Registra con un solo tocco
• Trascrizione completamente offline
• Calendario per sfogliare la tua storia
• Ricerca istantanea in tutte le voci
• Preferiti per i momenti che contano
• Comandi rapidi Siri per registrare ovunque
• Modalità chiara e scura

Voice Journal è per chiunque pensi meglio quando parla — terapeuti, scrittori, genitori, studenti o chiunque abbia bisogno di uno spazio tranquillo per pensare ad alta voce.

Inizia la tua prima voce oggi.\
""",
    "release_notes": "Correzioni di bug e miglioramenti delle prestazioni.",
},

"nl-NL": {
    "name": "Voice Journal – Spraakdagboek",
    "subtitle": "Privé spraakdagboek met AI",
    "keywords": "spraakdagboek,dagboek,stemming,reflectie,transcriptie,privacy,mindfulness,dankbaarheid",
    "description": """\
Voice Journal zet je gesproken gedachten om in een privé, doorzoekbaar dagboek — zonder typen.

Druk één keer en spreek vrij. Elk woord wordt direct op je apparaat getranscribeerd door lokale AI — geen internetverbinding nodig. Zodra je klaar bent met praten, worden je gedachten doorzoekbare tekst.

── PRIVÉ BY DESIGN ──
Niets verlaat ooit je telefoon. Geen account nodig, geen cloud, niemand anders kan je dagboekentries lezen. Alleen jij en je gedachten.

── ONTDEK JE PATRONEN ──
Elke entry krijgt een rustige AI-samenvatting, een stemmingslabel en terugkerende thema's. Na verloop van tijd zie je waaraan je gedachten het meest terugkeren.

── DAGELIJKSE INSPIRATIE ──
Elke dag brengt een nieuw reflectieonderwerp en een klein beetje motivatie — precies genoeg om te beginnen.

── ONTWORPEN VOOR HOE JIJ DENKT ──
• Opnemen met één tik
• Transcriptie volledig offline
• Agenda om je geschiedenis te bekijken
• Directe zoekfunctie in alle entries
• Favorieten voor bijzondere momenten
• Siri-opdrachten om overal op te nemen
• Lichte en donkere modus

Voice Journal is voor iedereen die beter denkt als ze praten — therapeuten, schrijvers, ouders, studenten of gewoon mensen die een rustige plek nodig hebben om hardop na te denken.

Begin vandaag met je eerste entry.\
""",
    "release_notes": "Bugfixes en prestatieverbeteringen.",
},

"sv": {
    "name": "Voice Journal – Röstdagbok",
    "subtitle": "Privat AI-röstdagbok, offline",
    "keywords": "röstdagbok,dagbok,humör,reflektion,transkription,integritet,mindfulness,tacksamhet",
    "description": """\
Voice Journal omvandlar dina talade tankar till en privat, sökbar dagbok — utan att behöva skriva.

Tryck en gång och prata fritt. Varje ord transkriberas direkt på din enhet med lokal AI — ingen internetanslutning krävs. Så fort du är klar med att prata blir dina tankar sökbar text.

── PRIVAT FRÅN GRUNDEN ──
Inget lämnar din telefon. Inget konto att skapa, ingen molnlagring, ingen annan kan läsa dina anteckningar. Bara du och dina tankar.

── UPPTÄCK DINA MÖNSTER ──
Varje anteckning får en diskret AI-sammanfattning, en stämningsmärkning och återkommande teman. Med tiden ser du vad ditt sinne återvänder till mest.

── DAGLIG INSPIRATION ──
Varje dag ger en ny reflektionsfråga och en liten portion motivation — precis tillräckligt för att komma igång.

── BYGGT FÖR DITT SÄTT ATT TÄNKA ──
• Spela in med ett enda tryck
• Transkription helt offline
• Kalender för att bläddra i din historia
• Direkt sökning i alla anteckningar
• Favoriter för stunder som betyder något
• Siri-genvägar för att spela in var som helst
• Ljust och mörkt läge

Voice Journal är för alla som tänker bättre när de pratar — terapeuter, skribenter, föräldrar, studenter eller alla som behöver en lugn plats för att tänka högt.

Börja din första anteckning idag.\
""",
    "release_notes": "Felkorrigeringar och prestandaförbättringar.",
},

"da": {
    "name": "Voice Journal – Taledagbog",
    "subtitle": "Privat AI-taledagbog, offline",
    "keywords": "taledagbog,dagbog,humør,refleksion,transskription,privatliv,mindfulness,taknemmelighed",
    "description": """\
Voice Journal omdanner dine talte tanker til en privat, søgbar dagbog — uden at skulle skrive.

Tryk én gang og tal frit. Hvert ord transskriberes direkte på din enhed med lokal AI — ingen internetforbindelse nødvendig. Så snart du er færdig med at tale, bliver dine tanker til søgbar tekst.

── PRIVAT AF DESIGN ──
Intet forlader nogensinde din telefon. Ingen konto at oprette, ingen sky-lagring, ingen andre kan læse dine indlæg. Kun dig og dine tanker.

── OPDAG DINE MØNSTRE ──
Hvert indlæg får en diskret AI-opsummering, et stemningsmærke og tilbagevendende temaer. Med tiden vil du se, hvad dit sind vender mest tilbage til.

── DAGLIG INSPIRATION ──
Hver dag bringer en ny refleksionsfråga og en lille portion motivation — præcis nok til at komme i gang.

── BYGGET TIL DIN TANKEGANG ──
• Optag med et enkelt tryk
• Transskription helt offline
• Kalender til at gennemse din historie
• Øjeblikkelig søgning i alle indlæg
• Favoritter til øjeblikke, der betyder noget
• Siri-genveje til at optage overalt
• Lyst og mørkt tema

Voice Journal er for alle, der tænker bedre, når de taler — terapeuter, forfattere, forældre, studerende eller alle, der har brug for et stille sted til at tænke højt.

Start din første indgang i dag.\
""",
    "release_notes": "Fejlrettelser og ydeevneforbedringer.",
},

"nb": {
    "name": "Voice Journal – Taledagbok",
    "subtitle": "Privat AI-taledagbok, offline",
    "keywords": "taledagbok,dagbok,humør,refleksjon,transkripsjon,personvern,mindfulness,takknemlighet",
    "description": """\
Voice Journal gjør om talte tanker til en privat, søkbar dagbok — uten å måtte skrive.

Trykk én gang og snakk fritt. Hvert ord transkriberes direkte på enheten din med lokal AI — ingen internettilkobling nødvendig. Så snart du er ferdig med å snakke, blir tankene dine søkbar tekst.

── PRIVAT BY DESIGN ──
Ingenting forlater telefonen din. Ingen konto å opprette, ingen skylagring, ingen andre kan lese innleggene dine. Bare deg og tankene dine.

── OPPDAG MØNSTRENE DINE ──
Hvert innlegg får et diskret AI-sammendrag, en stemningsetikett og tilbakevendende temaer. Over tid vil du se hva sinnet ditt oftest vender tilbake til.

── DAGLIG INSPIRASJON ──
Hver dag gir et nytt refleksjonsspørsmål og litt motivasjon — akkurat nok til å komme i gang.

── LAGET FOR DIN TENKEMÅTE ──
• Ta opp med ett trykk
• Transkripsjon helt offline
• Kalender for å se gjennom historikken din
• Øyeblikkelig søk i alle innlegg
• Favoritter for øyeblikkene som betyr noe
• Siri-snarveier for å ta opp hvor som helst
• Lyst og mørkt tema

Voice Journal er for alle som tenker bedre når de snakker — terapeuter, forfattere, foreldre, studenter eller alle som trenger et rolig sted for å tenke høyt.

Start din første oppføring i dag.\
""",
    "release_notes": "Feilrettinger og ytelsesforbedringer.",
},

"fi": {
    "name": "Voice Journal – Äänipäiväkirja",
    "subtitle": "Yksityinen AI-äänipäiväkirja",
    "keywords": "äänipäiväkirja,päiväkirja,mieliala,pohdinta,litterointi,yksityisyys,mindfulness,kiitollisuus",
    "description": """\
Voice Journal muuttaa puhutut ajatuksesi yksityiseksi, hakukelpoiseksi päiväkirjaksi — ei kirjoittamista tarvita.

Paina kerran ja puhu vapaasti. Jokainen sana litteroidaan suoraan laitteellasi paikallisella tekoälyllä — ei internet-yhteyttä tarvita. Heti kun olet puhunut, ajatuksesi muuttuvat hakukelpoiseksi tekstiksi.

── YKSITYISYYS SUUNNITTELUSTA LÄHTIEN ──
Mikään ei poistu puhelimestasi. Ei tiliä luotavaksi, ei pilvivarastointia, kukaan muu ei voi lukea merkintöjäsi. Vain sinä ja ajatuksesi.

── LÖYDÄ KAAVASI ──
Jokainen merkintä saa hiljaisen tekoälytiivistelmän, mielialatunnisteen ja toistuvat teemat. Ajan myötä näet, mihin mielesi palaa useimmiten.

── PÄIVITTÄINEN INSPIRAATIO ──
Joka päivä tuo uuden pohdintakysymyksen ja pienen annoksen motivaatiota — juuri tarpeeksi aloittamiseen.

── SUUNNITELTU AJATTELUTAVALLESI ──
• Äänitä yhdellä napautuksella
• Litterointi täysin offline-tilassa
• Kalenteri historiaasi selailemiseen
• Pikahaku kaikissa merkinnöissä
• Suosikit tärkeille hetkille
• Siri-pikakuvakkeet nauhoittamiseen missä tahansa
• Vaalea ja tumma tila

Voice Journal on kaikille, jotka ajattelevat paremmin puhuessaan — terapeutit, kirjailijat, vanhemmat, opiskelijat tai kaikki, jotka tarvitsevat rauhallisen paikan ajatella ääneen.

Aloita ensimmäinen merkintäsi tänään.\
""",
    "release_notes": "Virheenkorjaukset ja suorituskyvyn parannukset.",
},

"pl": {
    "name": "Voice Journal – Dziennik Głosu",
    "subtitle": "Prywatny dziennik głosowy AI",
    "keywords": "dziennik głosowy,dziennik,nastrój,refleksja,transkrypcja,prywatność,mindfulness,wdzięczność",
    "description": """\
Voice Journal zamienia mówione myśli w prywatny, przeszukiwalny dziennik — bez pisania.

Naciśnij raz i mów swobodnie. Każde słowo jest transkrybowane bezpośrednio na Twoim urządzeniu przez lokalną AI — bez połączenia z internetem. Gdy skończysz mówić, Twoje myśli stają się przeszukiwalnym tekstem.

── PRYWATNOŚĆ W PROJEKCIE ──
Nic nigdy nie opuszcza Twojego telefonu. Żadnego konta do tworzenia, żadnej chmury, nikt inny nie może czytać Twoich wpisów. Tylko Ty i Twoje myśli.

── ODKRYJ SWOJE WZORCE ──
Każdy wpis otrzymuje zwięzłe podsumowanie AI, etykietę nastroju i powtarzające się tematy. Z czasem zobaczysz, do czego Twój umysł najczęściej wraca.

── CODZIENNE ZACHĘTY ──
Każdy dzień przynosi nowe pytanie do refleksji i małą dawkę motywacji — dokładnie tyle, żeby zacząć.

── STWORZONY DLA TWOJEGO SPOSOBU MYŚLENIA ──
• Nagrywaj jednym dotknięciem
• Transkrypcja całkowicie offline
• Kalendarz do przeglądania historii
• Natychmiastowe wyszukiwanie we wszystkich wpisach
• Ulubione dla ważnych chwil
• Skróty Siri do nagrywania gdziekolwiek
• Jasny i ciemny motyw

Voice Journal jest dla wszystkich, którzy myślą lepiej, gdy mówią — terapeuci, pisarze, rodzice, studenci lub każdy, kto potrzebuje cichego miejsca do głośnego myślenia.

Zacznij swój pierwszy wpis już dziś.\
""",
    "release_notes": "Poprawki błędów i ulepszenia wydajności.",
},

"ru": {
    "name": "Voice Journal – Дневник Голоса",
    "subtitle": "Личный голосовой дневник с ИИ",
    "keywords": "голосовой дневник,дневник,настроение,рефлексия,транскрипция,приватность,осознанность,благодарность",
    "description": """\
Voice Journal превращает ваши устные мысли в приватный дневник с поиском — без набора текста.

Нажмите один раз и говорите свободно. Каждое слово транскрибируется прямо на вашем устройстве с помощью локального ИИ — без подключения к интернету. Как только вы закончите говорить, ваши мысли превращаются в текст с возможностью поиска.

── КОНФИДЕНЦИАЛЬНОСТЬ КАК ПРИНЦИП ──
Ничего никогда не покидает ваш телефон. Не нужно создавать аккаунт, нет облачного хранилища, никто другой не может читать ваши записи. Только вы и ваши мысли.

── ОТКРОЙТЕ СВОИ ПАТТЕРНЫ ──
Каждая запись получает краткое резюме от ИИ, метку настроения и повторяющиеся темы. Со временем вы увидите, к чему ваш ум возвращается чаще всего.

── ЕЖЕДНЕВНЫЙ СТИМУЛ ──
Каждый день приносит новый вопрос для размышления и немного мотивации — ровно столько, чтобы начать.

── СОЗДАНО ДЛЯ ВАШЕГО СПОСОБА ДУМАТЬ ──
• Запись одним нажатием
• Транскрипция полностью офлайн
• Календарь для просмотра истории
• Мгновенный поиск по всем записям
• Избранное для важных моментов
• Ярлыки Siri для записи где угодно
• Светлая и тёмная тема

Voice Journal — для всех, кто лучше думает, когда говорит: терапевты, писатели, родители, студенты или просто те, кому нужно тихое место для размышлений вслух.

Начните свою первую запись сегодня.\
""",
    "release_notes": "Исправление ошибок и улучшение производительности.",
},

"ar-SA": {
    "name": "Voice Journal – مذكرات صوتية",
    "subtitle": "مذكرات صوتية خاصة مع ذكاء",
    "keywords": "مذكرات صوتية,يوميات,تتبع المزاج,تأمل,نسخ صوتي,خصوصية,ماينفولنس,امتنان",
    "description": """\
يحوّل Voice Journal أفكارك المنطوقة إلى مذكرات خاصة وقابلة للبحث — دون الحاجة إلى الكتابة.

اضغط مرة واحدة وتكلم بحرية. يتم نسخ كل كلمة مباشرةً على جهازك بواسطة الذكاء الاصطناعي المحلي — دون الحاجة إلى اتصال بالإنترنت. فور انتهائك من الكلام، تتحول أفكارك إلى نص قابل للبحث.

── خصوصية بالتصميم ──
لا شيء يغادر هاتفك أبدًا. لا حاجة لإنشاء حساب، ولا تخزين سحابي، ولا يمكن لأحد قراءة مدوناتك. أنت وأفكارك فقط.

── اكتشف أنماطك ──
تحصل كل مدونة على ملخص ذكاء اصطناعي هادئ، وعلامة مزاجية، وموضوعات متكررة. مع مرور الوقت، ستدرك ما يشغل عقلك أكثر.

── دافع يومي ──
يأتي كل يوم بسؤال تأملي جديد وجرعة صغيرة من الحافز — بالضبط ما يكفي للبدء.

── مصمم لطريقة تفكيرك ──
• تسجيل بضغطة واحدة
• نسخ صوتي بالكامل دون إنترنت
• تقويم لاستعراض تاريخك
• بحث فوري في جميع المدونات
• المفضلة للحظات المهمة
• اختصارات Siri للتسجيل من أي مكان
• وضع فاتح وداكن

Voice Journal لكل من يفكر بشكل أفضل عند الكلام — المعالجون، الكتّاب، الآباء، الطلاب، أو أي شخص يحتاج إلى مكان هادئ للتفكير بصوت عالٍ.

ابدأ مدونتك الأولى اليوم.\
""",
    "release_notes": "إصلاح الأخطاء وتحسينات الأداء.",
},

"tr": {
    "name": "Voice Journal – Sesli Günlük",
    "subtitle": "Özel yapay zeka sesli günlük",
    "keywords": "sesli günlük,günlük,ruh hali takibi,yansıma,transkripsiyon,gizlilik,farkındalık,minnettarlık",
    "description": """\
Voice Journal, söylediğiniz düşünceleri özel ve aranabilir bir günlüğe dönüştürür — yazmadan.

Bir kez dokunun ve özgürce konuşun. Her kelime, yerel yapay zeka ile doğrudan cihazınızda transkribe edilir — internet bağlantısı gerekmez. Konuşmayı bitirdiğiniz anda düşünceleriniz aranabilir metne dönüşür.

── TASARIMDAN GELEN GİZLİLİK ──
Hiçbir şey telefonunuzu terk etmez. Hesap açmanız gerekmiyor, bulut depolama yok, başka kimse günlük notlarınızı okuyamaz. Sadece siz ve düşünceleriniz.

── KENDİ KALIPLARINIZİ KEŞFEDİN ──
Her giriş, sessiz bir yapay zeka özeti, ruh hali etiketi ve yinelenen temalar alır. Zamanla zihninizin en çok neye döndüğünü göreceksiniz.

── GÜNLÜK İLHAM ──
Her gün yeni bir yansıma sorusu ve küçük bir motivasyon gelir — başlamak için tam ihtiyacınız olan kadar.

── DÜŞÜNME ŞEKLİNİZE GÖRE TASARLANDI ──
• Tek dokunuşla kayıt
• Tamamen çevrimdışı transkripsiyon
• Geçmişinize göz atmak için takvim
• Tüm girişlerde anında arama
• Önemli anlar için favoriler
• Her yerden kayıt için Siri Kısayolları
• Açık ve koyu mod

Voice Journal, konuşarak daha iyi düşünenler için — terapistler, yazarlar, ebeveynler, öğrenciler veya sessizce yüksek sesle düşünebilecekleri bir yere ihtiyaç duyan herkes.

Bugün ilk girişinizi başlatın.\
""",
    "release_notes": "Hata düzeltmeleri ve performans iyileştirmeleri.",
},

}  # end LOCALES


def write_file(path, content):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def validate_limits(locale, data):
    warnings = []
    if len(data["name"]) > 30:
        warnings.append(f"  ⚠ name too long: {len(data['name'])} chars (max 30)")
    if len(data["subtitle"]) > 30:
        warnings.append(f"  ⚠ subtitle too long: {len(data['subtitle'])} chars (max 30)")
    if len(data["keywords"]) > 100:
        warnings.append(f"  ⚠ keywords too long: {len(data['keywords'])} chars (max 100)")
    if warnings:
        print(f"\n{locale}:")
        for w in warnings:
            print(w)


def main():
    for locale, data in LOCALES.items():
        validate_limits(locale, data)
        locale_dir = os.path.join(BASE, locale)
        os.makedirs(locale_dir, exist_ok=True)
        for field in ("name", "subtitle", "keywords", "description", "release_notes"):
            write_file(os.path.join(locale_dir, f"{field}.txt"), data[field])

    print(f"\n✓ Generated metadata for {len(LOCALES)} locales in {BASE}/")
    print("\nLocale summary:")
    for locale, data in LOCALES.items():
        n, s, k = len(data["name"]), len(data["subtitle"]), len(data["keywords"])
        status = "✓" if n <= 30 and s <= 30 and k <= 100 else "⚠"
        print(f"  {status} {locale:10s}  name={n:2d}/30  subtitle={s:2d}/30  keywords={k:3d}/100")


if __name__ == "__main__":
    main()
