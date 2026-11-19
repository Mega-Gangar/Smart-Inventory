class SmartRestockResponse {
  final List<InventoryPrediction> predictions;
  final List<AssociationRule> associationRules;

  SmartRestockResponse({required this.predictions, required this.associationRules});

  factory SmartRestockResponse.fromJson(Map<String, dynamic> json) {
    var predList = json['predictions'] as List? ?? [];
    var ruleList = json['association_rules'] as List? ?? [];

    List<InventoryPrediction> predictions = predList.map((i) => InventoryPrediction.fromJson(i)).toList();
    List<AssociationRule> rules = ruleList.map((i) => AssociationRule.fromJson(i)).toList();

    return SmartRestockResponse(predictions: predictions, associationRules: rules);
  }
}

class InventoryPrediction {
  final int productId;
  final String productName;
  final int currentStock;
  final double dailyVelocity;
  final int daysRemaining;
  final int reorderPoint;
  final bool needsReorder;
  final int recommendedOrderQty;
  final String status;

  InventoryPrediction({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.dailyVelocity,
    required this.daysRemaining,
    required this.reorderPoint,
    required this.needsReorder,
    required this.recommendedOrderQty,
    required this.status,
  });

  factory InventoryPrediction.fromJson(Map<String, dynamic> json) {
    return InventoryPrediction(
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      currentStock: json['current_stock'] ?? 0,
      dailyVelocity: (json['daily_velocity'] as num?)?.toDouble() ?? 0.0,
      daysRemaining: json['days_remaining'] ?? 999,
      reorderPoint: json['reorder_point'] ?? 0,
      needsReorder: json['needs_reorder'] ?? false,
      recommendedOrderQty: json['recommended_order_qty'] ?? 0,
      status: json['status'] ?? 'Optimal',
    );
  }
}

class AssociationRule {
  final List<String> antecedents;
  final List<String> consequents;
  final double support;
  final double confidence;
  final double lift;

  AssociationRule({
    required this.antecedents,
    required this.consequents,
    required this.support,
    required this.confidence,
    required this.lift,
  });

  factory AssociationRule.fromJson(Map<String, dynamic> json) {
    return AssociationRule(
      antecedents: List<String>.from(json['antecedents'] ?? []),
      consequents: List<String>.from(json['consequents'] ?? []),
      support: (json['support'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      lift: (json['lift'] as num?)?.toDouble() ?? 0.0,
    );
  }
}