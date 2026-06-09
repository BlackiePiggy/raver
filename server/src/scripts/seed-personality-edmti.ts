import 'dotenv/config';

const directDatabaseUrl = process.env.DIRECT_URL || process.env.DATABASE_URL;
if (directDatabaseUrl) {
  process.env.DATABASE_URL = directDatabaseUrl;
}

const APPLY = process.argv.includes('--apply');

const resultTypes = [
  {
    code: 'BOMB',
    mbtiCode: 'ESTJ',
    title: '鼓点暴脾气',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: 'Drop等不及急脾气、歌单强迫症晚期',
    genreMapping: 'Big Room House、经典Hardstyle（150BPM+强底鼓、锯齿波主奏、极简炸裂段落）',
    description:
      '谁懂啊！听到乱序歌单真的会抓狂！只爱规整炸裂的重鼓点，铺垫超过30秒就想快进。电音节必冲前排栏杆，自带控场气场，谁要是在你旁边瞎晃挡视线，直接一个白眼甩过去。',
    isHidden: false,
    sortOrder: 1,
  },
  {
    code: 'BOUN',
    mbtiCode: 'ESTP',
    title: '弹跳快乐狗',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '全场显眼包本包、Bounce无脑冲选手',
    genreMapping: 'Melbourne Bounce、EDM Commercial（128BPM魔性弹跳律动、反拍节奏、洗脑循环旋律）',
    description:
      '主打一个快乐至上！管它什么小众大众，能蹦就是好歌。电音节全程蹦跳不停，自带快乐buff，能带动周围所有人一起嗨。手机里全是蹦迪视频，朋友圈三天两头发“有没有一起蹦迪的搭子！”',
    isHidden: false,
    sortOrder: 2,
  },
  {
    code: 'HUG',
    mbtiCode: 'ESFJ',
    title: '旋律抱抱熊',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '朋友圈歌单分享机、情绪急救包',
    genreMapping: 'Melodic Future Bass、抒情Progressive House（柔和锯齿和弦、侧链泵感、人声切片治愈旋律）',
    description:
      '谁难过了都来找你要歌单！你的耳机永远分别人一半，歌单里全是温柔治愈的旋律。电音节会主动照顾社恐朋友，帮大家拍照、买水、占位置，是所有人的“电音妈妈”。',
    isHidden: false,
    sortOrder: 3,
  },
  {
    code: 'DISC',
    mbtiCode: 'ESFP',
    title: '复古迪斯科精',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '老歌考古学家、网红歌绝缘体',
    genreMapping: '90s Old School Disco、Vintage EDM、Classic House（复古四拍律动、模拟合成器音色、经典循环编排）',
    description:
      '什么新歌？我只听我爸妈当年蹦迪的歌！手机里全是80、90年代的Disco金曲，听到熟悉的旋律就忍不住扭起来。坚决抵制流水线网红歌，坚信“经典永不过时”。',
    isHidden: false,
    sortOrder: 4,
  },
  {
    code: 'NOTE',
    mbtiCode: 'ISTJ',
    title: '编曲笔记控',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '歌单分类狂魔、乐理半吊子学霸',
    genreMapping: 'Classic Trance、正统Progressive House（128-140BPM规整四拍、层次递进编曲、精准和声编排）',
    description:
      '听歌不听个三遍编曲细节，等于白听！歌单分类精细到“通勤专用”“摸鱼专用”“睡前专用”，连曲风BPM都标得清清楚楚。从不跟风听热门歌，只听经过自己严格审核的优质作品。',
    isHidden: false,
    sortOrder: 5,
  },
  {
    code: 'HEAD',
    mbtiCode: 'ISTP',
    title: '耳机炸头党',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '深夜颅内蹦迪选手、社恐蹦迪天花板',
    genreMapping: 'Rawstyle、Heavy Big Room、Dark EDM（失真硬核底鼓、短促炸裂Drop、低频冲击力拉满）',
    description:
      '表面安安静静，耳机里已经炸穿天花板了！从不线下蹦迪，只爱深夜窝在被窝里听重低音炸曲。音量必须开满，主打一个“我炸我自己，与别人无关”。',
    isHidden: false,
    sortOrder: 6,
  },
  {
    code: 'NIGHT',
    mbtiCode: 'ISFJ',
    title: '夜色被窝猫',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '深夜听歌特困生、被窝蹦迪达人',
    genreMapping: 'Chill Future Bass、Lofi EDM、氛围感慢电音（弱化重鼓、柔化音色、绵长氛围感铺垫）',
    description:
      '只有深夜的被窝和耳机，才是你的专属快乐星球！歌单里全是温柔舒缓的氛围感电音，睡前必听半小时才能睡着。从不主动分享歌单，把好听的旋律都私藏起来自己慢慢品。',
    isHidden: false,
    sortOrder: 7,
  },
  {
    code: 'DREAM',
    mbtiCode: 'ISFP',
    title: '迷幻做梦人',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '小众歌单收藏家、孤独浪漫代言人',
    genreMapping: 'Uplifting Trance、Melodic Techno（空灵穿梭合成器、长线旋律、沉浸式迷幻氛围）',
    description:
      '我的歌单里没有一首你听过的歌！只爱小众迷幻的Trance和Melodic Techno，听歌的时候感觉自己在宇宙里漫游。享受孤独，从不觉得一个人听歌无聊，反而觉得很自在。',
    isHidden: false,
    sortOrder: 8,
  },
  {
    code: 'DARK',
    mbtiCode: 'ENTJ',
    title: '地下黑老大',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '冷门歌挖掘机、审美鄙视链顶端',
    genreMapping: 'Industrial Techno、Experimental EDM、硬核地下曲风（工业冷感律动、细微音色迭代、先锋实验编排）',
    description:
      '什么网红歌？我听的歌你们三年后才会火！只爱地下Techno和实验电音，看不起听商业EDM的人。经常给朋友安利冷门好歌，然后得意地说“怎么样，我就说好听吧！”',
    isHidden: false,
    sortOrder: 9,
  },
  {
    code: 'MASH',
    mbtiCode: 'ENTP',
    title: '混搭整活怪',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: 'Mashup鬼才、什么都听杂食党',
    genreMapping: 'Mashup、创意Remix、全曲风融合实验（无曲风壁垒、混搭编排、创意音色重组）',
    description:
      '没有我不能混的曲风！国风+电音、摇滚+电音、甚至儿歌+电音，只要你敢想，我就敢混。歌单里什么曲风都有，主打一个“万物皆可电音”。',
    isHidden: false,
    sortOrder: 10,
  },
  {
    code: 'PARTY',
    mbtiCode: 'ENFJ',
    title: '电音局局长',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '电音搭子饲养员、正能量发电站',
    genreMapping: '国风EDM、Uplifting EDM、正能量燃系House（民乐融合、昂扬旋律、治愈热血氛围）',
    description:
      '别问，问就是我已经帮你组好电音局了！永远是第一个组织蹦迪的人，能把所有认识的人都拉进电音坑。性格开朗热情，和谁都能聊得来，是电音圈的社交天花板。',
    isHidden: false,
    sortOrder: 11,
  },
  {
    code: 'SUNNY',
    mbtiCode: 'ENFP',
    title: '阳光小太阳',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '永远的气氛组、新鲜感追逐者',
    genreMapping: 'Sunny EDM、Light Bounce、清新Progressive House（明亮音色、轻快律动、高活力氛围感）',
    description:
      '电音一响，我就是全场最亮的崽！永远充满活力，永远对新鲜事物充满好奇。喜欢尝试各种新曲风，听到好听的歌就会忍不住分享给所有人。和你在一起，永远不会觉得无聊。',
    isHidden: false,
    sortOrder: 12,
  },
  {
    code: 'COLD',
    mbtiCode: 'INTJ',
    title: '冷感冰块人',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: 'Techno高冷党、网红歌拉黑大师',
    genreMapping: 'Dark Techno、Minimal Techno（极简Loop、工业冷感、细微音色迭代、低饱和氛围）',
    description:
      '别给我推网红歌，我怕脏了我的歌单！只爱极简冷感的Techno，听歌的时候面无表情，仿佛全世界都与我无关。从不混圈，从不和人争论曲风高低，主打一个“你听你的，我听我的”。',
    isHidden: false,
    sortOrder: 13,
  },
  {
    code: 'GLIT',
    mbtiCode: 'INTP',
    title: '音色拆解怪',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '编曲细节狂魔、乐理脑洞大师',
    genreMapping: '复杂Experimental、Glitch EDM、技术性Remix（碎拍音色、glitch故障效果、复杂编曲结构）',
    description:
      '别人听歌听旋律，我听歌听这个音色是用什么合成器做的！沉迷拆解编曲结构、混音细节，经常为了一个音色研究好几天。歌单里全是技术流实验电音，普通人根本听不懂。',
    isHidden: false,
    sortOrder: 14,
  },
  {
    code: 'AMBI',
    mbtiCode: 'INFJ',
    title: '氛围造梦师',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '氛围感天花板、孤独浪漫诗人',
    genreMapping: 'Dream Trance、Ambient EDM（绵长铺底音色、空灵声场、无压沉浸式幻境氛围）',
    description:
      '我的耳机里有一整个宇宙！只爱空灵氛围感的Ambient和Dream Trance，听歌的时候会脑补出各种故事和画面。内心敏感细腻，能从旋律中感受到别人感受不到的情绪。',
    isHidden: false,
    sortOrder: 15,
  },
  {
    code: 'PURE',
    mbtiCode: 'INFP',
    title: '纯白初心者',
    subtitle: '全中国最稀有的电音人格',
    slangTagline: '纯粹听歌佛系党、无流派热爱者',
    genreMapping: 'Pure Melodic EDM、Healing Chillwave（干净音色、无攻击性律动、治愈纯旋律）',
    description:
      '管它什么曲风，好听就是好歌！从不纠结流派，不深究乐理，不攀比圈层，单纯喜欢电音带来的快乐。性格佛系松弛，从不和人争论，觉得“听歌嘛，开心最重要”。',
    isHidden: false,
    sortOrder: 16,
  },
  {
    code: 'DRUNK',
    mbtiCode: null,
    title: '酒鬼蹦迪人',
    subtitle: '恭喜您触发了隐藏人格！',
    slangTagline: '电音节酒蒙子、不醉不归选手',
    genreMapping: '所有能蹦的曲风（喝多了什么都好听）',
    description:
      '电音节对你来说就是大型喝酒现场，电音只是下酒菜。喝多了什么曲风都爱听，什么人都能聊，蹦迪能从开场蹦到散场，第二天醒来完全不记得发生了什么。',
    isHidden: true,
    sortOrder: 17,
  },
  {
    code: 'HHHH',
    mbtiCode: null,
    title: '傻乐者',
    subtitle: '恭喜您触发了终极隐藏人格！',
    slangTagline: '电音快乐废物、听什么都开心',
    genreMapping: '所有曲风（只要能让我开心）',
    description:
      '你的脑回路过于清奇，连16种常规模板都按不住你。你听电音不挑曲风，不挑歌手，不挑场合，只要有电音就开心。主打一个“傻乐就完事了”，是电音圈最纯粹的快乐源泉。',
    isHidden: true,
    sortOrder: 18,
  },
  {
    code: 'CPDD',
    mbtiCode: null,
    title: '搭子狂魔',
    subtitle: '恭喜您触发稀有隐藏人格！',
    slangTagline: '电音搭子收割机、蹦迪专属粘人精、线下组队狂热粉',
    genreMapping: '全品类狂欢EDM、弹跳Bounce、热门炸场金曲（所有适合组队蹦迪、氛围感拉满的大众燃系曲风）',
    description:
      '别人蹦迪为听歌，你蹦迪为找搭子！对你来说电音只是氛围感背景，找合拍、会蹦、懂梗的电音搭子才是终极目标。线上常驻CPDD，线下主动组队，社牛属性拉满，不喜欢独自听歌蹦迪，坚信“蹦迪一定要热闹，有人陪伴才够嗨”。',
    isHidden: true,
    sortOrder: 19,
  },
  {
    code: 'PHOENIX',
    mbtiCode: null,
    title: '凤凰很行',
    subtitle: '恭喜你触发圈内玩梗隐藏人格！',
    slangTagline: '凤凰护短狂魔、Illenium死忠粉、专治“凤凰不行”杠精',
    genreMapping: 'Illenium专属未来贝斯、抒情炸裂EDM、氛围感旋律电音（标志性温柔撕裂音色、情绪递进Drop、治愈系燃情旋律）',
    description:
      '全网公认的Illenium终极死忠，圈内经典梗“凤凰不行”在你这里完全失效！别人跟风吐槽凤凰曲风单一、审美固化，只有你懂他旋律里的温柔与炸裂，歌单一半以上全是凤凰的神仙作品，循环无数遍永不腻。',
    isHidden: true,
    sortOrder: 20,
  },
] as const;

type SeedOption = {
  text: string;
  directResultCode?: string | null;
  scorePayload?: Record<string, number>;
};

type SeedQuestion = {
  sortOrder: number;
  stemText: string;
  isEasterEgg?: boolean;
  options: SeedOption[];
};

const regularQuestions: SeedQuestion[] = [
  {
    sortOrder: 1,
    stemText: '深夜独处放空时，你的耳机专属 BGM 会偏向哪种？',
    options: [
      { text: '炸穿天灵盖的重低音硬核曲，用强劲鼓点扫空所有烦闷', scorePayload: { TF: 2, EI: -1 } },
      { text: '能飘起来的空灵氛围感旋律，温柔律动包裹独处情绪', scorePayload: { TF: -2, EI: -1 } },
      { text: '爸妈当年蹦迪的经典复古 Disco，熟悉旋律自带安稳怀旧感', scorePayload: { SN: 2, JP: 1 } },
      { text: '没人听过的小众实验律动电音，偏爱独特冷门的听觉质感', scorePayload: { SN: -2, JP: -1 } },
    ],
  },
  {
    sortOrder: 2,
    stemText: '去电音节，你最真实的状态是？',
    options: [
      { text: '直冲前排栏杆，全程蹦跳不停，带动周围所有人一起嗨', scorePayload: { EI: 2, JP: -1 } },
      { text: '躲在角落独自卡点，不社交不凑热闹，主打一个沉浸式自嗨', scorePayload: { EI: -2, JP: 1 } },
      { text: '提前做好攻略，几点到、看谁、站哪里都规划得明明白白', scorePayload: { JP: 2, EI: -1 } },
      { text: '随缘逛，走到哪听到哪，遇到喜欢的就多待一会', scorePayload: { JP: -2, EI: 1 } },
    ],
  },
  {
    sortOrder: 3,
    stemText: '关于你的私人歌单，日常状态更贴合？',
    options: [
      { text: '分类精细到“通勤专用”“摸鱼专用”“睡前专用”，连 BPM 都标得清清楚楚', scorePayload: { JP: 2, TF: 1 } },
      { text: '随心随手收藏，国风+电音+摇滚+儿歌混在一起，主打一个乱炖', scorePayload: { JP: -2, TF: -1 } },
      { text: '全是百大 DJ 经典曲目和热门爆款，永不过时不踩雷', scorePayload: { SN: 2, JP: 1 } },
      { text: '全是地下小众制作人作品，没有一首是别人听过的', scorePayload: { SN: -2, JP: -1 } },
    ],
  },
  {
    sortOrder: 4,
    stemText: '刷到爆红的网红电音曲目，你的第一反应是？',
    options: [
      { text: '好听就循环，管它什么网红不网红，快乐最重要', scorePayload: { SN: 2, JP: -1 } },
      { text: '立刻拉黑，谁听网红歌谁 low，我只听地下小众曲', scorePayload: { SN: -2, TF: 1 } },
      { text: '分享给所有电音搭子，约好下次蹦迪一起嗨', scorePayload: { EI: 2, TF: -1 } },
      { text: '默默收藏，自己偷偷听，不告诉任何人', scorePayload: { EI: -2, JP: 1 } },
    ],
  },
  {
    sortOrder: 5,
    stemText: '生活压力爆棚、情绪烦躁时，电音对你而言是？',
    options: [
      { text: '情绪宣泄利器，靠硬核炸场 drop 把所有烦恼都炸飞', scorePayload: { TF: 2, EI: 1 } },
      { text: '温柔治愈港湾，靠细腻旋律抚平内心的所有内耗', scorePayload: { TF: -2, EI: -1 } },
      { text: '按心情切换歌单，不同情绪听不同的歌', scorePayload: { JP: 2, TF: 1 } },
      { text: '随便放什么都行，只要有声音就好', scorePayload: { JP: -2, TF: -1 } },
    ],
  },
  {
    sortOrder: 6,
    stemText: '挖到一首本命神仙电音，你会如何分享这份快乐？',
    options: [
      { text: '立刻外放+发朋友圈+私发给所有好友，恨不得全世界都听到', scorePayload: { EI: 2, TF: -1 } },
      { text: '私藏耳机独享，默默循环一周，谁都不告诉', scorePayload: { EI: -2, JP: 1 } },
      { text: '分析它的编曲结构和混音细节，写一篇长文安利', scorePayload: { TF: 2, JP: 1 } },
      { text: '分享给最懂你的那个电音搭子，一起沉浸式欣赏', scorePayload: { TF: -2, EI: -1 } },
    ],
  },
  {
    sortOrder: 7,
    stemText: '对待听歌审美，你的一贯态度是？',
    options: [
      { text: '审美固定专一，十年如一日只听一种曲风，绝不轻易改变', scorePayload: { JP: 2, SN: 1 } },
      { text: '审美极度包容，什么曲风都听，今天爱这个明天爱那个', scorePayload: { JP: -2, SN: -1 } },
      { text: '只听经过时间验证的经典作品，拒绝快餐式新歌', scorePayload: { SN: 2, JP: 1 } },
      { text: '永远追新，只听刚发布的新歌和新人作品', scorePayload: { SN: -2, JP: -1 } },
      { text: '唯凤凰独尊！别人吐槽“凤凰不行”直接反驳护短', directResultCode: 'PHOENIX' },
    ],
  },
  {
    sortOrder: 8,
    stemText: '挑选常驻单曲的核心标准，你更看重？',
    options: [
      { text: '旋律上口洗脑，听一遍就能哼，主打一个直白快乐', scorePayload: { SN: 2, EI: 1 } },
      { text: '编曲层次丰富，细节满满，越听越有味道', scorePayload: { SN: -2, TF: 1 } },
      { text: '节奏强劲有力，能让我瞬间充满能量', scorePayload: { TF: 2, EI: 1 } },
      { text: '情感真挚动人，能让我产生强烈共鸣', scorePayload: { TF: -2, EI: -1 } },
    ],
  },
  {
    sortOrder: 9,
    stemText: '线下奔赴电音现场，你的核心诉求是？',
    options: [
      { text: '认识新朋友+蹦迪+拍照发朋友圈，主打一个社交狂欢', scorePayload: { EI: 2, TF: -1 } },
      { text: '单纯听歌，谁都别打扰我，听完本命曲目立刻走人', scorePayload: { EI: -2, TF: 1 } },
      { text: '打卡所有知名 DJ 的演出，一个都不能落下', scorePayload: { JP: 2, SN: 1 } },
      { text: '随便逛逛，遇到好听的就多待一会，开心最重要', scorePayload: { JP: -2, SN: -1 } },
    ],
  },
  {
    sortOrder: 10,
    stemText: '聆听一首完整电音，你最偏爱哪个段落？',
    options: [
      { text: '高潮爆燃 drop，铺垫什么的都不重要，只要炸就完事了', scorePayload: { TF: 2, EI: 1 } },
      { text: '细腻前奏与铺垫，循序渐进的氛围感才是灵魂', scorePayload: { TF: -2, EI: -1 } },
      { text: '经典副歌部分，旋律朗朗上口，百听不厌', scorePayload: { SN: 2, JP: 1 } },
      { text: '间奏部分，各种创意音色和节奏变化最有意思', scorePayload: { SN: -2, JP: -1 } },
    ],
  },
  {
    sortOrder: 11,
    stemText: '周末松弛休憩，你的电音放松模式是？',
    options: [
      { text: '出门奔赴电音节/夜店，嗨到凌晨才回家', scorePayload: { EI: 2, JP: -1 } },
      { text: '宅家被窝云蹦迪，边吃零食边听歌，主打一个躺平', scorePayload: { EI: -2, TF: -1 } },
      { text: '按计划听完整张专辑，认真品味每一首歌', scorePayload: { JP: 2, SN: 1 } },
      { text: '随机播放歌单，听到什么算什么', scorePayload: { JP: -2, SN: -1 } },
    ],
  },
  {
    sortOrder: 12,
    stemText: '长期听歌习惯里，你更倾向于？',
    options: [
      { text: '固定场景听固定歌单，通勤听这个，学习听那个，绝不乱换', scorePayload: { JP: 2, TF: 1 } },
      { text: '随时随地想听就听，没有任何规则，随机切歌全看缘分', scorePayload: { JP: -2, SN: -1 } },
      { text: '只听自己熟悉的歌单，很少尝试新歌', scorePayload: { SN: 2, EI: -1 } },
      { text: '每天都在找新歌听，歌单更新速度极快', scorePayload: { SN: -2, JP: -1 } },
    ],
  },
  {
    sortOrder: 13,
    stemText: '你的歌单主力曲风更贴近？',
    options: [
      { text: '主流 EDM、Bounce、复古 Disco，大众百搭不踩雷', scorePayload: { SN: 2, EI: 1 } },
      { text: 'Techno、Trance、硬核、实验电音，小众高级不撞款', scorePayload: { SN: -2, EI: -1 } },
      { text: '重低音炸曲、硬核 Hardstyle，主打一个宣泄解压', scorePayload: { TF: 2, EI: 1 } },
      { text: '治愈系 Future Bass、Chillwave，温柔又治愈', scorePayload: { TF: -2, EI: -1 } },
    ],
  },
  {
    sortOrder: 14,
    stemText: '电音带给你的核心情绪价值是？',
    options: [
      { text: '提神续命+宣泄压力，没有电音我根本活不下去', scorePayload: { TF: 2, JP: 1 } },
      { text: '治愈情绪+享受浪漫，电音是我的精神避难所', scorePayload: { TF: -2, JP: -1 } },
      { text: '社交媒介+认识同好，电音让我交到了很多朋友', scorePayload: { EI: 2, TF: -1 } },
      { text: '独处陪伴+精神寄托，电音是我最好的朋友', scorePayload: { EI: -2, TF: -1 } },
    ],
  },
  {
    sortOrder: 15,
    stemText: '播放模式的常年选择是？',
    options: [
      { text: '单曲循环，一首好听的歌能循环一个月', scorePayload: { JP: 2, EI: -1 } },
      { text: '全局随机，永远不知道下一首会是什么，充满惊喜', scorePayload: { JP: -2, EI: 1 } },
      { text: '列表循环，按顺序听完整个歌单', scorePayload: { SN: 2, JP: 1 } },
      { text: '智能推荐，让算法给我惊喜', scorePayload: { SN: -2, JP: -1 } },
    ],
  },
  {
    sortOrder: 16,
    stemText: '面对全新电音作品，你的接纳姿态是？',
    options: [
      { text: '先看别人评价，大家都说好听我再听', scorePayload: { SN: 2, JP: 1 } },
      { text: '主动挖掘新人新作，永远走在潮流最前端', scorePayload: { SN: -2, EI: 1 } },
      { text: '拉上朋友一起听，边听边吐槽', scorePayload: { EI: 2, TF: 1 } },
      { text: '自己先听一遍，觉得好听再分享给别人', scorePayload: { EI: -2, TF: -1 } },
    ],
  },
];

const easterEggQuestion: SeedQuestion = {
  sortOrder: 17,
  isEasterEgg: true,
  stemText: '去电音节/夜店，你的核心终极目的是？',
  options: [
    { text: '滴酒不沾，纯靠电音嗨，专注听歌蹦迪' },
    { text: '喝一点，微醺状态最好，氛围感拉满就行' },
    { text: '必须喝到断片，不醉不归', directResultCode: 'DRUNK' },
    { text: '主打一个 CPDD！找合拍电音搭子，随缘组队贴贴', directResultCode: 'CPDD' },
  ],
};

const log = (stage: string, detail?: Record<string, unknown>): void => {
  if (detail) {
    console.log(`[seed-personality-edmti] ${stage}`, detail);
  } else {
    console.log(`[seed-personality-edmti] ${stage}`);
  }
};

const questions = [...regularQuestions, easterEggQuestion];

async function main(): Promise<void> {
  const { PrismaClient, QuizQuestionStatus } = await import('@prisma/client');
  const prisma = new PrismaClient();

  try {
    log('boot', { apply: APPLY, resultTypeCount: resultTypes.length, questionCount: questions.length });

    if (!APPLY) {
      const existingResultTypeCount = await prisma.personalityResultType.count();
      const existingQuestionCount = await prisma.personalityQuestion.count();
      log('dry-run', {
        existingResultTypeCount,
        existingQuestionCount,
        plannedResultTypes: resultTypes.map((item) => item.code),
        plannedQuestionSortOrders: questions.map((item) => item.sortOrder),
      });
      return;
    }

    const regularQuestionIds: string[] = [];
    let easterEggQuestionId: string | null = null;

    for (const resultType of resultTypes) {
      await prisma.personalityResultType.upsert({
        where: { code: resultType.code },
        update: {
          title: resultType.title,
          subtitle: resultType.subtitle,
          slangTagline: resultType.slangTagline,
          genreMapping: resultType.genreMapping,
          description: resultType.description,
          sortOrder: resultType.sortOrder,
          isActive: true,
          isHidden: resultType.isHidden,
          mbtiCode: resultType.mbtiCode,
        },
        create: {
          code: resultType.code,
          title: resultType.title,
          subtitle: resultType.subtitle,
          slangTagline: resultType.slangTagline,
          genreMapping: resultType.genreMapping,
          description: resultType.description,
          sortOrder: resultType.sortOrder,
          isActive: true,
          isHidden: resultType.isHidden,
          mbtiCode: resultType.mbtiCode,
        },
      });
    }
    log('result-types:seeded', { count: resultTypes.length });

    for (const question of questions) {
      const existing = await prisma.personalityQuestion.findFirst({
        where: { sortOrder: question.sortOrder },
        select: { id: true },
      });

      const row = existing
        ? await prisma.personalityQuestion.update({
            where: { id: existing.id },
            data: {
              status: QuizQuestionStatus.active,
              stemText: question.stemText,
              stemImageUrl: null,
              sortOrder: question.sortOrder,
              isEasterEgg: Boolean(question.isEasterEgg),
            },
          })
        : await prisma.personalityQuestion.create({
            data: {
              status: QuizQuestionStatus.active,
              stemText: question.stemText,
              stemImageUrl: null,
              sortOrder: question.sortOrder,
              isEasterEgg: Boolean(question.isEasterEgg),
            },
          });

      await prisma.personalityQuestionOption.deleteMany({ where: { questionId: row.id } });
      await prisma.personalityQuestionOption.createMany({
        data: question.options.map((option, index) => ({
          questionId: row.id,
          text: option.text,
          imageUrl: null,
          sortOrder: index,
          scorePayload: (option.scorePayload ?? {}) as any,
          directResultCode: option.directResultCode ?? null,
        })),
      });

      if (question.isEasterEgg) {
        easterEggQuestionId = row.id;
      } else {
        regularQuestionIds.push(row.id);
      }
    }
    log('questions:seeded', { regularCount: regularQuestionIds.length, easterEggQuestionId });

    const allQuestionIds = [...regularQuestionIds, ...(easterEggQuestionId ? [easterEggQuestionId] : [])];
    const existingConfig = await prisma.personalityConfig.findUnique({ where: { id: 'default' } });

    await prisma.personalityConfig.upsert({
      where: { id: 'default' },
      update: {
        isEnabled: existingConfig?.isEnabled ?? false,
        questionCount: 16,
        axisThreshold: 9,
        resultTypeCapacity: 32,
        standardQuestionIds: regularQuestionIds,
        debugQuestionIds: allQuestionIds,
        easterEggQuestionId,
        hiddenResultPriority: ['PHOENIX', 'CPDD', 'DRUNK', 'HHHH'],
      },
      create: {
        id: 'default',
        isEnabled: false,
        questionCount: 16,
        axisThreshold: 9,
        resultTypeCapacity: 32,
        standardQuestionIds: regularQuestionIds,
        debugQuestionIds: allQuestionIds,
        easterEggQuestionId,
        hiddenResultPriority: ['PHOENIX', 'CPDD', 'DRUNK', 'HHHH'],
      },
    });
    log('config:seeded', { regularQuestionIds, easterEggQuestionId });

    log('done', { apply: APPLY });
  } finally {
    await prisma.$disconnect();
  }
}

void main().catch((error) => {
  console.error('[seed-personality-edmti] failed', error);
  process.exitCode = 1;
});
