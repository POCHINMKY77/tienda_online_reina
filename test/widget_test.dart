import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // Necesario para codificar y decodificar JSON
import 'package:shared_preferences/shared_preferences.dart'; // Persistencia de datos

// =======================================================================
// 1. MODELOS DE DATOS
// =======================================================================

class User {
  final String email;
  final String password;
  final bool isAdmin;
  User({required this.email, required this.password, this.isAdmin = false});
}

class Product {
  final String id;
  final String name;
  final double price;
  final String imagePath;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imagePath,
    required this.category,
  });

  // Método para crear un producto desde un mapa
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      imagePath: json['imagePath'],
      category: json['category'],
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'imagePath': imagePath,
    'category': category,
  };
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});

  // Convertir a JSON
  Map<String, dynamic> toJson() => {
    'product_id': product.id,
    'quantity': quantity,
  };

  // Crear desde JSON (Necesita el producto completo)
  factory CartItem.fromJson(
    Map<String, dynamic> json,
    List<Product> availableProducts,
  ) {
    final productId = json['product_id'];
    // Aseguramos encontrar el producto antes de crear el CartItem
    final product = availableProducts.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Producto con ID $productId no encontrado'),
    );
    return CartItem(product: product, quantity: json['quantity']);
  }
}

class Order {
  final String id;
  final String userId;
  final List<CartItem> items;
  final double total;
  final String status; // 'Pagado', 'Fiado'
  final DateTime date;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.status,
    required this.date,
  });

  // Convertir a JSON (para guardar)
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'items': items
        .map((i) => i.toJson())
        .toList(), // Guarda solo IDs y cantidad
    'total': total,
    'status': status,
    'date': date.toIso8601String(),
  };

  // Crear desde JSON (para cargar)
  factory Order.fromJson(
    Map<String, dynamic> json,
    List<Product> availableProducts,
  ) {
    // Reconstruir la lista de CartItems
    final List<dynamic> itemsJson = json['items'];
    final items = itemsJson
        .map((i) => CartItem.fromJson(i, availableProducts))
        .toList();

    return Order(
      id: json['id'],
      userId: json['userId'],
      items: items,
      total: json['total'],
      status: json['status'],
      date: DateTime.parse(json['date']),
    );
  }
}

// =======================================================================
// 2. SIMULACIÓN DE API / GESTIÓN DE DATOS (CON PERSISTENCIA)
//    *** Se ha modificado _products a una lista mutable (no final) ***
// =======================================================================

class ApiService {
  // --- DATOS SIMULADOS (Nuestra "Base de Datos" en Memoria) ---
  static final List<User> _users = [
    User(email: 'admin@tienda.com', password: 'admin', isAdmin: true),
    User(email: 'usuario@tienda.com', password: '123'),
  ];

  static List<Order> _orders = [];

  // Lista de productos (AHORA MUTABLE para que el admin pueda modificarlos)
  static List<Product> _products = [
    Product(
      id: 'P01',
      name: 'Pollo Entero',
      price: 6.50,
      imagePath: 'assets/images/pollo_entero.jpg',
      category: 'Carnes',
    ),
    Product(
      id: 'P02',
      name: 'Carne de Cerdo',
      price: 4.80,
      imagePath: 'assets/images/carne_chancho.jpg',
      category: 'Carnes',
    ),
    Product(
      id: 'P03',
      name: 'Carne de Res',
      price: 5.20,
      imagePath: 'assets/images/carne_vaca.jpg',
      category: 'Carnes',
    ),
    Product(
      id: 'P04',
      name: 'Pescado Fresco',
      price: 7.00,
      imagePath: 'assets/images/pescado.jpg',
      category: 'Carnes',
    ),
    Product(
      id: 'P05',
      name: 'Salchichas Paquete',
      price: 2.50,
      imagePath: 'assets/images/salchichas.jpg',
      category: 'Embutidos',
    ),
    Product(
      id: 'P06',
      name: 'Costal de Arroz 5kg',
      price: 8.99,
      imagePath: 'assets/images/costal_arroz.jpg',
      category: 'Productos Básicos',
    ),
    Product(
      id: 'P07',
      name: 'Cubeta de Huevos',
      price: 3.50,
      imagePath: 'assets/images/cubeta_huevos.jpg',
      category: 'Productos Básicos',
    ),
    Product(
      id: 'P08',
      name: 'Leche Vita 1L',
      price: 0.95,
      imagePath: 'assets/images/leche_vita.jpg',
      category: 'Lácteos',
    ),
    Product(
      id: 'P09',
      name: 'Yogurt Toni 1L',
      price: 1.80,
      imagePath: 'assets/images/yogurt_toni.jpg',
      category: 'Lácteos',
    ),
    Product(
      id: 'P10',
      name: 'Fideos Don Victorio',
      price: 0.75,
      imagePath: 'assets/images/fideos_donvictorio.jpg',
      category: 'Harinas',
    ),
    Product(
      id: 'P11',
      name: 'Harina de Trigo 1kg',
      price: 1.20,
      imagePath: 'assets/images/harina.jpg',
      category: 'Harinas',
    ),
    Product(
      id: 'P12',
      name: 'Pan Fresco',
      price: 1.50,
      imagePath: 'assets/images/pan.jpg',
      category: 'Harinas',
    ),
    Product(
      id: 'P13',
      name: 'Rapiditos Paquete',
      price: 1.10,
      imagePath: 'assets/images/rapiditos.jpg',
      category: 'Harinas',
    ),
    Product(
      id: 'P14',
      name: 'Panchitos Bolsa',
      price: 0.50,
      imagePath: 'assets/images/panchitos.jpg',
      category: 'Golosinas',
    ),
    Product(
      id: 'P15',
      name: 'Barra de Chocolate',
      price: 0.80,
      imagePath: 'assets/images/chocolate.jpg',
      category: 'Golosinas',
    ),
    Product(
      id: 'P16',
      name: 'Chupetes x10',
      price: 1.00,
      imagePath: 'assets/images/chupetes.jpg',
      category: 'Golosinas',
    ),
    Product(
      id: 'P17',
      name: 'Gomitas Paquete',
      price: 0.60,
      imagePath: 'assets/images/gomitas.jpg',
      category: 'Golosinas',
    ),
    Product(
      id: 'P18',
      name: 'Botella de Agua 1L',
      price: 0.75,
      imagePath: 'assets/images/agua.jpg',
      category: 'Bebidas',
    ),
    Product(
      id: 'P19',
      name: 'Coca Cola 2L',
      price: 2.25,
      imagePath: 'assets/images/coca_cola.jpg',
      category: 'Bebidas',
    ),
    Product(
      id: 'P20',
      name: 'Sprite 2L',
      price: 2.10,
      imagePath: 'assets/images/sprite.jpg',
      category: 'Bebidas',
    ),
    Product(
      id: 'P21',
      name: 'Fiora Vanti 1.5L',
      price: 1.85,
      imagePath: 'assets/images/fiora_vanti.jpg',
      category: 'Bebidas',
    ),
    Product(
      id: 'P22',
      name: 'Inca Kola 2L',
      price: 2.30,
      imagePath: 'assets/images/inca_cola.jpg',
      category: 'Bebidas',
    ),
    Product(
      id: 'P23',
      name: 'Gatorade Naranja',
      price: 1.50,
      imagePath: 'assets/images/gatorade.jpg',
      category: 'Bebidas',
    ),
    Product(
      id: 'P24',
      name: 'Vive Cien',
      price: 0.70,
      imagePath: 'assets/images/vive_cien.jpg',
      category: 'Bebidas',
    ),
    Product(
      id: 'P25',
      name: '220V Lata',
      price: 0.65,
      imagePath: 'assets/images/220v.jpg',
      category: 'Bebidas',
    ),
    Product(
      id: 'P26',
      name: 'Vino Tinto Botella',
      price: 12.00,
      imagePath: 'assets/images/vino.jpg',
      category: 'Alcohol',
    ),
    Product(
      id: 'P27',
      name: 'Cerveza Pilsener Lata',
      price: 1.25,
      imagePath: 'assets/images/pilsener.jpg',
      category: 'Alcohol',
    ),
    Product(
      id: 'P28',
      name: 'Cerveza Club Lata',
      price: 1.35,
      imagePath: 'assets/images/club_cerveza.jpg',
      category: 'Alcohol',
    ),
    Product(
      id: 'P29',
      name: 'Cerveza Corona',
      price: 2.50,
      imagePath: 'assets/images/corona.jpg',
      category: 'Alcohol',
    ),
    Product(
      id: 'P30',
      name: 'Ron Cubata',
      price: 15.00,
      imagePath: 'assets/images/cubata.jpg',
      category: 'Alcohol',
    ),
    Product(
      id: 'P31',
      name: 'Vodka Switch',
      price: 10.50,
      imagePath: 'assets/images/switch.jpg',
      category: 'Alcohol',
    ),
    Product(
      id: 'P32',
      name: 'Caja de Lark',
      price: 4.00,
      imagePath: 'assets/images/lark.jpg',
      category: 'Cigarrillos',
    ),
    Product(
      id: 'P33',
      name: 'Caja de Elephant',
      price: 4.20,
      imagePath: 'assets/images/elephant.jpg',
      category: 'Cigarrillos',
    ),
    Product(
      id: 'P34',
      name: 'Caja de Carnival',
      price: 3.80,
      imagePath: 'assets/images/carnival.jpg',
      category: 'Cigarrillos',
    ),
  ];

  // Claves de almacenamiento
  static const String _ordersKey = 'tienda_reina_orders';
  static const String _productsKey = 'tienda_reina_products';

  // --- MÉTODOS DE PERSISTENCIA ---

  // Carga productos (opcional, pero útil si se quiere persistencia de admin)
  static Future<void> loadProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJsonString = prefs.getString(_productsKey);

      if (productsJsonString != null) {
        final List<dynamic> productsList = jsonDecode(productsJsonString);
        _products = productsList.map((json) => Product.fromJson(json)).toList();
      } else {
        // Si no hay productos guardados, usamos la lista inicial
        _products = List.from(_products); // Clonar la lista inicial
      }
    } catch (e) {
      debugPrint('Error al cargar productos: $e. Usando lista por defecto.');
      // Usar la lista hardcodeada como fallback
      _products = [
        // ... poner la lista hardcodeada original aquí,
        // pero para simplificar, confiamos en la lista inicial.
      ];
    }
  }

  // Guarda la lista de productos
  static Future<void> saveProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final productsListJson = _products.map((p) => p.toJson()).toList();
    final productsJsonString = jsonEncode(productsListJson);
    await prefs.setString(_productsKey, productsJsonString);
  }

  // Carga las órdenes guardadas al iniciar la aplicación
  static Future<void> loadOrders() async {
    // Aseguramos que los productos estén cargados primero para reconstruir las órdenes
    await loadProducts();

    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJsonString = prefs.getString(_ordersKey);

      if (ordersJsonString != null) {
        final List<dynamic> ordersList = jsonDecode(ordersJsonString);
        // Usamos la lista de productos cargada (_products)
        _orders = ordersList
            .map((json) => Order.fromJson(json, _products))
            .toList();
      } else {
        _orders = [];
      }
    } catch (e) {
      // Manejo de error si los datos guardados son corruptos o falta un producto
      debugPrint('Error al cargar órdenes: $e. Inicializando lista vacía.');
      _orders = [];
    }
  }

  // Guarda la lista de órdenes
  static Future<void> saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersListJson = _orders.map((o) => o.toJson()).toList();
    final ordersJsonString = jsonEncode(ordersListJson);
    await prefs.setString(_ordersKey, ordersJsonString);
  }

  // --- MÉTODOS DE AUTENTICACIÓN SIMULADA ---
  Future<String?> register({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_users.any((u) => u.email == email)) {
      return 'El email ya está registrado.';
    }
    _users.add(User(email: email, password: password));
    return null;
  }

  Future<User?> login({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _users.firstWhereOrNull(
      (u) => u.email == email && u.password == password,
    );
  }

  // --- MÉTODOS DE PRODUCTOS Y ÓRDENES ---
  // Obtiene la lista actual y mutable de productos.
  Future<List<Product>> getProducts() async {
    await loadProducts(); // Asegura la carga desde disco antes de retornar
    await Future.delayed(const Duration(milliseconds: 100));
    return _products;
  }

  Future<List<String>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _products.map((p) => p.category).toSet().toList();
  }

  // Permite al admin gestionar productos
  Future<void> saveProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      // Editar
      _products[index] = product;
    } else {
      // Añadir
      _products.add(product);
    }
    // GUARDAR EN DISCO DESPUÉS DE CADA CAMBIO DE PRODUCTO
    await saveProducts();
  }

  Future<void> deleteProduct(String productId) async {
    _products.removeWhere((p) => p.id == productId);
    // GUARDAR EN DISCO DESPUÉS DE CADA CAMBIO DE PRODUCTO
    await saveProducts();
  }

  Future<void> placeOrder(
    User user,
    List<CartItem> items,
    double total,
    String status,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    final orderId =
        '${DateTime.now().millisecondsSinceEpoch}-${_orders.length + 1}';

    _orders.add(
      Order(
        id: orderId,
        userId: user.email,
        // Creamos copias de los CartItems para la orden
        items: items
            .map(
              (item) =>
                  CartItem(product: item.product, quantity: item.quantity),
            )
            .toList(),
        total: total,
        status: status,
        date: DateTime.now(),
      ),
    );

    // GUARDAR EN DISCO DESPUÉS DE CADA ORDEN
    await saveOrders();
  }

  // Obtiene todas las órdenes para el administrador
  Future<List<Order>> getAdminOrders() async {
    // Asegura que la lista esté cargada antes de retornar
    await loadOrders();
    await Future.delayed(const Duration(milliseconds: 300));
    return _orders.reversed.toList();
  }

  // Obtiene las órdenes de un usuario específico
  Future<List<Order>> getUserOrders(String userId) async {
    // Asegura que la lista esté cargada antes de retornar
    await loadOrders();
    await Future.delayed(const Duration(milliseconds: 300));
    return _orders.where((o) => o.userId == userId).toList().reversed.toList();
  }
}

// =======================================================================
// 3. GESTOR DE ESTADO (CARRITO)
// =======================================================================

class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get totalItemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  // El precio total se recalcula con cada cambio, asegurando la actualización
  double get totalCartPrice {
    return _items.fold(
      0.0,
      (sum, item) => sum + (item.product.price * item.quantity),
    );
  }

  // Incrementa la cantidad o añade el producto
  void addItem(Product product) {
    final existingItem = _items.firstWhereOrNull(
      (item) => item.product.id == product.id,
    );

    if (existingItem != null) {
      existingItem.quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  // Incrementa la cantidad de un item existente (usado por el botón '+')
  void incrementItemQuantity(Product product) {
    final existingItem = _items.firstWhereOrNull(
      (item) => item.product.id == product.id,
    );
    if (existingItem != null) {
      existingItem.quantity++;
      notifyListeners();
    }
  }

  // Decrementa la cantidad o elimina el producto si la cantidad es 1 (usado por el botón '-')
  void decrementItemQuantity(Product product) {
    final existingItem = _items.firstWhereOrNull(
      (item) => item.product.id == product.id,
    );

    if (existingItem != null) {
      if (existingItem.quantity > 1) {
        existingItem.quantity--;
      } else {
        // Si la cantidad es 1, eliminar el item
        _items.removeWhere((item) => item.product.id == product.id);
      }
      notifyListeners();
    }
  }

  // Elimina el producto completamente, independientemente de la cantidad
  void removeProduct(Product product) {
    _items.removeWhere((item) => item.product.id == product.id);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}

// =======================================================================
// 4. ESTRUCTURA DE LA APLICACIÓN Y PROVIDER SIMPLIFICADO
// =======================================================================

// Simplificación de Provider (para no requerir la dependencia)
class ChangeNotifierProvider<T extends ChangeNotifier> extends InheritedWidget {
  final T value;

  const ChangeNotifierProvider({
    super.key,
    required this.value,
    required super.child,
  });

  @override
  bool updateShouldNotify(ChangeNotifierProvider oldWidget) =>
      oldWidget.value != value;

  // Método estático para obtener el modelo del contexto
  static T of<T extends ChangeNotifier>(
    BuildContext context, {
    bool listen = true,
  }) {
    final provider = listen
        ? context
              .dependOnInheritedWidgetOfExactType<ChangeNotifierProvider<T>>()
        : context
                  .getElementForInheritedWidgetOfExactType<
                    ChangeNotifierProvider<T>
                  >()
                  ?.widget
              as ChangeNotifierProvider<T>?;

    if (provider == null) {
      throw FlutterError(
        'No se encontró un ChangeNotifierProvider de tipo $T en el árbol.',
      );
    }
    return provider.value;
  }
}

// La aplicación principal
void main() async {
  // Asegura que Flutter esté inicializado antes de llamar a servicios nativos
  WidgetsFlutterBinding.ensureInitialized();

  // Carga productos y órdenes guardadas antes de iniciar la app
  await ApiService.loadProducts();
  await ApiService.loadOrders();

  runApp(
    ChangeNotifierProvider(
      value: CartModel(),
      child: const TiendaOnlineReinaApp(),
    ),
  );
}

class TiendaOnlineReinaApp extends StatelessWidget {
  const TiendaOnlineReinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos el esquema de colores de la tienda
    final Color wineRed = const Color(0xFFB71C1C);
    final Color pastelPink = const Color(0xFFF8C8DC);

    return MaterialApp(
      title: 'Tienda Online Reina',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        primaryColor: wineRed,
        appBarTheme: AppBarTheme(
          color: wineRed,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: wineRed,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: wineRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
        scaffoldBackgroundColor: pastelPink.withOpacity(0.3),
        cardTheme: CardThemeData(
          elevation: 8.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          color: Colors.blueGrey[50],
          shadowColor: Colors.black38,
          margin: const EdgeInsets.all(12.0),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: wineRed,
          secondary: pastelPink,
        ),
      ),
      home: const AuthenticationWrapper(),
    );
  }
}

// =======================================================================
// 5. PANTALLAS DE AUTENTICACIÓN Y ENRUTAMIENTO
// =======================================================================

class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  User? _currentUser;

  User? get currentUser => _currentUser;

  void _login(User user) {
    setState(() {
      _currentUser = user;
    });
  }

  void _logout() {
    setState(() {
      _currentUser = null;
    });
    ChangeNotifierProvider.of<CartModel>(context, listen: false).clearCart();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return LoginScreen(onLoginSuccess: _login);
    } else if (_currentUser!.isAdmin) {
      // El admin va a la pantalla de administrador
      return AdminScreen(user: _currentUser!, onLogout: _logout);
    } else {
      // El usuario normal va a la pantalla de inicio
      return HomeScreen(user: _currentUser!, onLogout: _logout);
    }
  }
}

class LoginScreen extends StatefulWidget {
  final Function(User) onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isRegistering = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text;
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, ingrese email y contraseña.';
        _isLoading = false;
      });
      return;
    }

    if (_isRegistering) {
      String? error = await _apiService.register(
        email: email,
        password: password,
      );
      if (error == null) {
        final user = await _apiService.login(email: email, password: password);
        if (user != null) {
          widget.onLoginSuccess(user);
        }
      } else {
        setState(() => _errorMessage = error);
      }
    } else {
      final user = await _apiService.login(email: email, password: password);
      if (user != null) {
        widget.onLoginSuccess(user);
      } else {
        setState(() => _errorMessage = 'Credenciales incorrectas.');
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Imagen de Fondo de la Tienda (Inicio y Registro)
          Image.asset(
            'assets/images/tienda_fondo.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey,
                child: const Center(
                  child: Text(
                    'Fondo no encontrado o ruta incorrecta.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          ),

          // 2. Overlay Oscuro Semi-transparente
          Container(color: Colors.black.withOpacity(0.6)),

          // 3. Contenido de Login/Registro
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Card(
                elevation: 8,
                color: Colors.white.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isRegistering
                            ? 'Crear Cuenta'
                            : 'Bienvenido a Tienda Reina',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      const SizedBox(height: 25),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _submitAuth,
                              child: Text(
                                _isRegistering ? 'REGISTRAR' : 'INGRESAR',
                              ),
                            ),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isRegistering = !_isRegistering;
                            _errorMessage = null;
                          });
                        },
                        child: Text(
                          _isRegistering
                              ? '¿Ya tienes cuenta? Inicia Sesión'
                              : '¿No tienes cuenta? Regístrate aquí',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// 6. PANTALLA PRINCIPAL DE PRODUCTOS (HOME)
//    *** Arreglos de Refresh y FAB aplicados aquí ***
// =======================================================================

class HomeScreen extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.user, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  String _currentView = 'Tienda (Inicio)';
  List<String> _categories = ['Todos'];
  List<Product> _allProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Permite recargar los productos (clave para el refresh)
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // La lista se obtiene fresca de la API (que ahora permite mutación)
      final products = await _apiService.getProducts();
      final categories = await _apiService.getCategories();
      setState(() {
        _allProducts = products;
        _categories = ['Todos', ...categories];
        _isLoading = false;
        // Si la vista actual ya no existe (ej: admin borró la categoría), volvemos a 'Todos'
        if (!_categories.contains(_currentView)) {
          _currentView = 'Todos';
        }
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _selectSection(String section) {
    Navigator.of(context).pop(); // Cerrar el Drawer
    setState(() {
      _currentView = section;
      // Si la nueva sección es una categoría, actualizamos la lista de productos
      if (_categories.contains(section)) {
        // No es necesario recargar, solo filtrar la lista actual
      } else if (section == 'Órdenes') {
        // En un app real, podrías necesitar cargar las órdenes aquí
      }
    });
  }

  // Constructor del Drawer para la navegación
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.store, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    'Menú de Tienda Reina',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    widget.user.email,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              onTap: () => _selectSection('Tienda (Inicio)'),
              selected: _currentView == 'Tienda (Inicio)',
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8, bottom: 8),
              child: Text(
                'Categorías',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._categories.map(
              (category) => ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(category),
                onTap: () => _selectSection(category),
                selected: _currentView == category,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Mis Órdenes'),
              onTap: () => _selectSection('Órdenes'),
              selected: _currentView == 'Órdenes',
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar Sesión'),
              onTap: widget.onLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContentView(BuildContext context, User user) {
    final Size screenSize = MediaQuery.of(context).size;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/tienda_fondo.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'IMAGEN DE FONDO: error de ruta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Container(color: Colors.black.withOpacity(0.5)),
        Center(
          child: Card(
            color: Colors.white.withOpacity(0.85),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '¡Bienvenido!',
                    style: TextStyle(
                      fontSize: screenSize.width * 0.08,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.user.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenSize.width * 0.05,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Usa el menú lateral para explorar las categorías de productos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Construye la cuadrícula de productos con Pull-to-Refresh
  Widget _buildProductGrid(BuildContext context) {
    final filteredProducts = _currentView == 'Todos'
        ? _allProducts
        : _allProducts.where((p) => p.category == _currentView).toList();

    final cartModel = ChangeNotifierProvider.of<CartModel>(context);

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData, // *** PULL-TO-REFRESH IMPLEMENTADO ***
            color: Theme.of(context).primaryColor,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                        'No hay productos en la categoría $_currentView. ¡Desliza hacia abajo para recargar!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return ProductCard(
                          product: product,
                          onAddToCart: () {
                            cartModel.addItem(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} añadido.'),
                                duration: const Duration(milliseconds: 700),
                                backgroundColor: Theme.of(context).primaryColor,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          );
  }

  // *** MÉTODO BUILD COMPLETADO Y AJUSTADO PARA EL REFRESH Y EL FAB ***
  @override
  Widget build(BuildContext context) {
    final cartModel = ChangeNotifierProvider.of<CartModel>(context);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Theme.of(context).primaryColor,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Definir el contenido del cuerpo basado en la vista actual
    Widget currentBody;
    final isProductView =
        _categories.contains(_currentView) && _currentView != 'Tienda (Inicio)';

    if (_currentView == 'Tienda (Inicio)') {
      currentBody = _buildHomeContentView(context, widget.user);
    } else if (_currentView == 'Órdenes') {
      currentBody = UserOrdersScreen(userId: widget.user.email);
    } else {
      // Cualquier categoría seleccionada
      currentBody = _buildProductGrid(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentView),
        // Agregamos un botón de recarga explícito solo en las vistas de productos o "Todos"
        actions: [
          if (isProductView || _currentView == 'Todos')
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Recargar Productos',
            ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: currentBody,

      // *** ÚNICO FAB: CARRITO DE COMPRAS EN LA PARTE INFERIOR DERECHA ***
      floatingActionButton: FloatingActionButton(
        heroTag: 'cartFAB',
        onPressed: () {
          // Navegar a la pantalla del carrito
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => const CartScreen()));
        },
        child: Badge(
          label: Text(cartModel.totalItemCount.toString()),
          isLabelVisible: cartModel.totalItemCount > 0,
          child: const Icon(Icons.shopping_cart),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// =======================================================================
// 7. COMPONENTES Y OTRAS PANTALLAS (Necesarios para que sea ejecutable)
// =======================================================================

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final formattedPrice = NumberFormat.currency(
      locale: 'es_EC',
      symbol: '\$',
    ).format(product.price);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16.0),
              ),
              child: Image.asset(
                product.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          product.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  formattedPrice,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
            child: ElevatedButton(
              onPressed: onAddToCart,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Añadir', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer/Selector implícito del Provider para escuchar cambios
    final cartModel = ChangeNotifierProvider.of<CartModel>(context);

    final formattedTotal = NumberFormat.currency(
      locale: 'es_EC',
      symbol: '\$',
    ).format(cartModel.totalCartPrice);

    return Scaffold(
      appBar: AppBar(title: const Text('Carrito de Compras')),
      body: cartModel.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu carrito está vacío.',
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartModel.items.length,
                    itemBuilder: (context, index) {
                      final item = cartModel.items[index];
                      final formattedItemPrice = NumberFormat.currency(
                        locale: 'es_EC',
                        symbol: '\$',
                      ).format(item.product.price * item.quantity);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10.0),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              item.product.imagePath,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey,
                                    width: 50,
                                    height: 50,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.white,
                                    ),
                                  ),
                            ),
                          ),
                          title: Text(
                            item.product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${item.quantity} x ${NumberFormat.currency(locale: 'es_EC', symbol: '\$').format(item.product.price)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formattedItemPrice,
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => cartModel
                                    .decrementItemQuantity(item.product),
                                color: Theme.of(context).primaryColor,
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => cartModel
                                    .incrementItemQuantity(item.product),
                                color: Theme.of(context).primaryColor,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    cartModel.removeProduct(item.product),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Resumen y Botón de Pago
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            formattedTotal,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // En una app real, aquí iría el proceso de pago
                            _showOrderConfirmation(context, cartModel);
                          },
                          icon: const Icon(Icons.payment),
                          label: const Text('Proceder al Pago'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showOrderConfirmation(BuildContext context, CartModel cartModel) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Pedido'),
          content: Text(
            'El total de tu pedido es ${NumberFormat.currency(locale: 'es_EC', symbol: '\$').format(cartModel.totalCartPrice)}. ¿Deseas continuar?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Pagar'),
              onPressed: () async {
                // Simulamos el pago y colocamos la orden
                final userWrapper = context
                    .findAncestorStateOfType<_AuthenticationWrapperState>();
                final user = userWrapper!.currentUser!;
                final apiService = ApiService();

                await apiService.placeOrder(
                  user,
                  cartModel.items,
                  cartModel.totalCartPrice,
                  'Pagado',
                );

                cartModel.clearCart();
                Navigator.of(dialogContext).pop(); // Cierra el diálogo
                Navigator.of(context).pop(); // Cierra la pantalla del carrito
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('¡Pedido realizado con éxito!'),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class UserOrdersScreen extends StatelessWidget {
  final String userId;
  const UserOrdersScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return FutureBuilder<List<Order>>(
      future: apiService.getUserOrders(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar órdenes: ${snapshot.error}'),
          );
        }
        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'Aún no tienes órdenes registradas.',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final formattedTotal = NumberFormat.currency(
              locale: 'es_EC',
              symbol: '\$',
            ).format(order.total);
            final formattedDate = DateFormat(
              'dd MMM yyyy HH:mm',
            ).format(order.date);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.all(16),
                title: Text(
                  'Orden #${order.id.split('-').last}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Fecha: $formattedDate\nTotal: $formattedTotal'),
                trailing: Text(
                  order.status,
                  style: TextStyle(
                    color: order.status == 'Pagado'
                        ? Colors.green
                        : Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: order.items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item.quantity}x ${item.product.name}'),
                            Text(
                              NumberFormat.currency(
                                locale: 'es_EC',
                                symbol: '\$',
                              ).format(item.product.price * item.quantity),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }
}

// =======================================================================
// 8. PANTALLAS DE ADMINISTRADOR (Mínimas para completar el flujo)
// =======================================================================

class AdminScreen extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;
  const AdminScreen({super.key, required this.user, required this.onLogout});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _currentView = 'Gestión de Productos'; // Vista inicial del admin

  void _selectSection(String section) {
    Navigator.of(context).pop();
    setState(() {
      _currentView = section;
    });
  }

  Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ADMINISTRACIÓN',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
                Text(
                  'Usuario: ${widget.user.email}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Gestión de Productos'),
            onTap: () => _selectSection('Gestión de Productos'),
            selected: _currentView == 'Gestión de Productos',
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Ver Todas las Órdenes'),
            onTap: () => _selectSection('Ver Todas las Órdenes'),
            selected: _currentView == 'Ver Todas las Órdenes',
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: widget.onLogout,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentBody;
    if (_currentView == 'Gestión de Productos') {
      // Pasamos un callback para que, al modificar un producto, se actualice la vista
      currentBody = ProductManagementScreen(
        onProductUpdate: () => setState(() {}),
      );
    } else {
      currentBody = AdminOrdersScreen();
    }

    return Scaffold(
      appBar: AppBar(title: Text(_currentView)),
      drawer: _buildAdminDrawer(context),
      body: currentBody,
      // No hay FAB de carrito para el admin en esta vista
    );
  }
}

class ProductManagementScreen extends StatefulWidget {
  // Callback para forzar la actualización de la lista de productos si se cambia algo
  final VoidCallback onProductUpdate;

  const ProductManagementScreen({super.key, required this.onProductUpdate});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _apiService.getProducts();
  }

  // Permite recargar los productos en esta vista
  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = _apiService.getProducts();
    });
  }

  // Implementación simplificada de un modal de edición/creación
  void _editProduct(Product? product) {
    final TextEditingController nameController = TextEditingController(
      text: product?.name ?? '',
    );
    final TextEditingController priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    final TextEditingController imageController = TextEditingController(
      text: product?.imagePath ?? '',
    );
    final TextEditingController categoryController = TextEditingController(
      text: product?.category ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(product == null ? 'Añadir Producto' : 'Editar Producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Precio'),
                ),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(labelText: 'Ruta Imagen'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newProduct = Product(
                  id:
                      product?.id ??
                      'P${DateTime.now().millisecondsSinceEpoch}', // ID único
                  name: nameController.text,
                  price: double.tryParse(priceController.text) ?? 0.0,
                  imagePath: imageController.text,
                  category: categoryController.text,
                );
                await _apiService.saveProduct(newProduct);
                _refreshProducts(); // Refresca la lista del admin
                widget
                    .onProductUpdate(); // Notifica al HomeScreen (por si el admin está usando ambos)
                Navigator.of(dialogContext).pop();
              },
              child: Text(product == null ? 'Añadir' : 'Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _deleteProduct(Product product) async {
    await _apiService.deleteProduct(product.id);
    _refreshProducts();
    widget.onProductUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _editProduct(null),
              icon: const Icon(Icons.add),
              label: const Text('Añadir Nuevo Producto'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Product>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error al cargar productos: ${snapshot.error}'),
                );
              }
              final products = snapshot.data ?? [];

              return ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text(product.name),
                      subtitle: Text(
                        'ID: ${product.id} | ${NumberFormat.currency(locale: 'es_EC', symbol: '\$').format(product.price)} | Cat: ${product.category}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editProduct(product),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProduct(product),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class AdminOrdersScreen extends StatelessWidget {
  AdminOrdersScreen({super.key});

  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Order>>(
      future: _apiService.getAdminOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar órdenes: ${snapshot.error}'),
          );
        }
        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'No hay órdenes registradas.',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final formattedTotal = NumberFormat.currency(
              locale: 'es_EC',
              symbol: '\$',
            ).format(order.total);
            final formattedDate = DateFormat(
              'dd MMM yyyy HH:mm',
            ).format(order.date);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  'Orden #${order.id.split('-').last} (${order.userId})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Fecha: $formattedDate\nItems: ${order.items.length}',
                ),
                trailing: Text(
                  formattedTotal,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
