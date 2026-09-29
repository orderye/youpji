/// 贵州行政区域与经纬度模型
class GuizhouCity {
  final String name; // 如 "贵阳市"
  final String shortName; // 如 "贵阳"
  final double longitude;
  final double latitude;
  final String description;
  final String weather;
  final bool isCapital;
  final String? coverImageUrl; // 城市宣传/地标封面大图

  const GuizhouCity({
    required this.name,
    required this.shortName,
    required this.longitude,
    required this.latitude,
    required this.description,
    this.weather = '晴 22°C',
    this.isCapital = false,
    this.coverImageUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'short_name': shortName,
        'longitude': longitude,
        'latitude': latitude,
        'description': description,
        'weather': weather,
        'is_capital': isCapital,
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      };

  factory GuizhouCity.fromJson(Map<String, dynamic> json) => GuizhouCity(
        name: json['name'] as String? ?? '贵阳市',
        shortName: json['short_name'] as String? ?? '贵阳',
        longitude: (json['longitude'] as num?)?.toDouble() ?? 106.630153,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 26.647661,
        description: json['description'] as String? ?? '',
        weather: json['weather'] as String? ?? '晴 22°C',
        isCapital: json['is_capital'] as bool? ?? false,
        coverImageUrl: json['cover_image_url'] as String?,
      );
}

/// 贵州 9 个市（州）中心坐标基准数据与头图配置
class GuizhouCities {
  static const GuizhouCity guiyang = GuizhouCity(
    name: '贵阳市',
    shortName: '贵阳',
    longitude: 106.630153,
    latitude: 26.647661,
    description: '林城贵阳 · 省会枢纽 · 人文生态',
    weather: '晴 22°C',
    isCapital: true,
    coverImageUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80',
  );

  static const GuizhouCity anshun = GuizhouCity(
    name: '安顺市',
    shortName: '安顺',
    longitude: 105.947594,
    latitude: 26.253089,
    description: '瀑乡安顺 · 黄果树 · 龙宫 · 屯堡文化',
    weather: '多云 21°C',
    coverImageUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80',
  );

  static const GuizhouCity zunyi = GuizhouCity(
    name: '遵义市',
    shortName: '遵义',
    longitude: 106.927271,
    latitude: 27.725454,
    description: '红色圣地 · 遵义会议 · 赤水丹霞 · 酱酒之乡',
    weather: '晴 23°C',
    coverImageUrl: 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80',
  );

  static const GuizhouCity qiandongnan = GuizhouCity(
    name: '黔东南苗族侗族自治州',
    shortName: '黔东南',
    longitude: 107.98117,
    latitude: 26.56689,
    description: '千户苗寨 · 肇兴侗寨 · 民族非遗风情',
    weather: '阴 20°C',
    coverImageUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80',
  );

  static const GuizhouCity qiannan = GuizhouCity(
    name: '黔南布依族苗族自治州',
    shortName: '黔南',
    longitude: 107.52358,
    latitude: 26.26444,
    description: '荔波大小七孔 · 中国天眼 FAST · 绿宝石',
    weather: '多云 22°C',
    coverImageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
  );

  static const GuizhouCity qianxinan = GuizhouCity(
    name: '黔西南布依族苗族自治州',
    shortName: '黔西南',
    longitude: 104.90638,
    latitude: 25.08779,
    description: '万峰林 · 马岭河峡谷 · 户外运动胜地',
    weather: '晴 24°C',
    coverImageUrl: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
  );

  static const GuizhouCity bijie = GuizhouCity(
    name: '毕节市',
    shortName: '毕节',
    longitude: 105.29132,
    latitude: 27.30198,
    description: '百里杜鹃 · 织金洞 · 韭菜坪高原风光',
    weather: '阴 18°C',
    coverImageUrl: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1200&q=80',
  );

  static const GuizhouCity tongren = GuizhouCity(
    name: '铜仁市',
    shortName: '铜仁',
    longitude: 109.18956,
    latitude: 27.71835,
    description: '梵净山 · 佛光圣境 · 锦江风光',
    weather: '小雨 21°C',
    coverImageUrl: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1200&q=80',
  );

  static const GuizhouCity liupanshui = GuizhouCity(
    name: '六盘水市',
    shortName: '六盘水',
    longitude: 104.83042,
    latitude: 25.59063,
    description: '中国凉都 · 乌蒙大草原 · 玉舍滑雪',
    weather: '晴 17°C',
    coverImageUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80',
  );

  static const List<GuizhouCity> all = [
    guiyang,
    anshun,
    zunyi,
    qiandongnan,
    qiannan,
    qianxinan,
    bijie,
    tongren,
    liupanshui,
  ];

  static GuizhouCity findByName(String name) {
    final cleaned = name.replaceAll('市', '').replaceAll('州', '').trim();
    for (final c in all) {
      if (c.name.contains(cleaned) || c.shortName.contains(cleaned)) {
        return c;
      }
    }
    return guiyang;
  }
}
