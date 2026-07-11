import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CartItem
// ─────────────────────────────────────────────────────────────────────────────
class CartItem {
  final String itemId;
  final String name;
  final double price;
  final String imageUrl;
  final String categoryId;
  final bool   vatApplicable; // true = item is VAT chargeable
  final double vatRate;       // 0.0, 5.0, or 20.0
  int quantity;

  CartItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    this.vatApplicable = false,
    this.vatRate       = 0.0,
    this.quantity      = 1,
  });

  double get subtotal => price * quantity;

  /// VAT-inclusive extraction: VAT element = lineTotal − (lineTotal / (1 + rate/100))
  double get vatAmount {
    if (!vatApplicable || vatRate == 0) return 0.0;
    final lineTotal = price * quantity;
    return double.parse((lineTotal - (lineTotal / (1 + vatRate / 100))).toStringAsFixed(2));
  }

  Map<String, dynamic> toMap() => {
        'itemId':        itemId,
        'name':          name,
        'price':         price,
        'imageUrl':      imageUrl,
        'categoryId':    categoryId,
        'quantity':      quantity,
        'vatApplicable': vatApplicable,
        'vatRate':       vatRate,
        'vatAmount':     vatAmount,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
//  CartService  —  singleton, in-memory, notifies listeners on change
// ─────────────────────────────────────────────────────────────────────────────
class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  // ── State ──────────────────────────────────────────────────────────────────
  final List<CartItem> _items = [];
  String? _restaurantId;
  String? _restaurantName;
  double  _deliveryFee  = 0;
  int     _deliveryMins = 30;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<CartItem> get items          => List.unmodifiable(_items);
  String?        get restaurantId   => _restaurantId;
  String?        get restaurantName => _restaurantName;
  double         get deliveryFee    => _deliveryFee;
  int            get deliveryMins   => _deliveryMins;
  bool           get isEmpty        => _items.isEmpty;
  int            get totalItems     => _items.fold(0, (s, e) => s + e.quantity);

  double get subtotal      => _items.fold(0.0, (s, e) => s + e.subtotal);
  double get foodVatTotal  => double.parse(
      _items.fold(0.0, (s, e) => s + e.vatAmount).toStringAsFixed(2));
  double get total         => subtotal + _deliveryFee;

  int quantityOf(String itemId) =>
      _items.where((i) => i.itemId == itemId).fold(0, (s, i) => s + i.quantity);

  // ── Mutators ───────────────────────────────────────────────────────────────

  /// Returns true if the cart was cleared (i.e. different restaurant).
  bool setRestaurant({
    required String restaurantId,
    required String restaurantName,
    required double deliveryFee,
    required int deliveryMins,
  }) {
    if (_restaurantId != null && _restaurantId != restaurantId && _items.isNotEmpty) {
      return false; // caller must ask user to clear
    }
    _restaurantId   = restaurantId;
    _restaurantName = restaurantName;
    _deliveryFee    = deliveryFee;
    _deliveryMins   = deliveryMins;
    return true;
  }

  void addItem(CartItem item) {
    final existing = _items.where((i) => i.itemId == item.itemId).firstOrNull;
    if (existing != null) {
      existing.quantity++;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeOne(String itemId) {
    final existing = _items.where((i) => i.itemId == itemId).firstOrNull;
    if (existing == null) return;
    if (existing.quantity > 1) {
      existing.quantity--;
    } else {
      _items.remove(existing);
    }
    notifyListeners();
  }

  void removeItem(String itemId) {
    _items.removeWhere((i) => i.itemId == itemId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _restaurantId   = null;
    _restaurantName = null;
    _deliveryFee    = 0;
    _deliveryMins   = 30;
    notifyListeners();
  }
}
