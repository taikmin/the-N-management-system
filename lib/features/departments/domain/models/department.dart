/// 부서 모델 (호텔 조직 단위)
///
/// 예: 프론트 데스크, 하우스키핑, F&B, 시설/유지보수, 경영지원
/// 관리자(Manager 이상)가 생성/수정/삭제 가능.
class Department {
  const Department({
    required this.id,
    required this.name,
    this.description,
    this.color = '#0ABAB5',
    this.leadId,
    this.leadName,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String color; // hex color like '#0ABAB5'
  final String? leadId; // FK profiles.id (팀장)
  final String? leadName; // join된 팀장 이름
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: json['color'] as String? ?? '#0ABAB5',
      leadId: json['lead_id'] as String?,
      leadName: json['lead'] != null
          ? (json['lead'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      sortOrder: (json['sort_order'] as int?) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'description': description,
        'color': color,
        'lead_id': leadId,
        'sort_order': sortOrder,
      };

  Map<String, dynamic> toUpdateJson() => toInsertJson();

  Department copyWith({
    String? id,
    String? name,
    String? Function()? description,
    String? color,
    String? Function()? leadId,
    String? Function()? leadName,
    int? sortOrder,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description != null ? description() : this.description,
      color: color ?? this.color,
      leadId: leadId != null ? leadId() : this.leadId,
      leadName: leadName != null ? leadName() : this.leadName,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
