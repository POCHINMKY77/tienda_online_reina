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

  // Método para crear un producto desde un mapa (necesario para el carrito/órdenes)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      imagePath: json['imagePath'],
      category: json['category'],
    );
  }
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
// =======================================================================

class ApiService {
  // --- DATOS SIMULADOS (Nuestra "Base de Datos" en Memoria) ---
  static final List<User> _users = [
    User(email: 'admin@tienda.com', password: 'admin', isAdmin: true),
    User(email: 'usuario@tienda.com', password: '123'),
  ];

  // Lista de órdenes
  static List<Order> _orders = [];

  // Lista de productos (debe ser estática para reconstruir órdenes)
  static final List<Product> _products = [
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

  // Clave de almacenamiento
  static const String _ordersKey = 'tienda_reina_orders';

  // --- MÉTODOS DE PERSISTENCIA ---

  // Carga las órdenes guardadas al iniciar la aplicación
  static Future<void> loadOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJsonString = prefs.getString(_ordersKey);

      if (ordersJsonString != null) {
        final List<dynamic> ordersList = jsonDecode(ordersJsonString);
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
  Future<List<Product>> getProducts() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _products;
  }

  Future<List<String>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _products.map((p) => p.category).toSet().toList();
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
        // Creamos copias de los CartItems para que la orden tenga un snapshot de la cantidad en ese momento
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
// 4. ESTRUCTURA DE LA APLICACIÓN
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

  // Corregido: La anotación @SuppressWarnings no existe en Dart/Flutter
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

  // Carga las órdenes guardadas antes de iniciar la app
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
      return AdminScreen(user: _currentUser!, onLogout: _logout);
    } else {
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
      // CORRECCIÓN: Se eliminó el doble 'required' del API service.
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _apiService.getProducts();
      final categories = await _apiService.getCategories();
      setState(() {
        _allProducts = products;
        _categories = ['Todos', ...categories];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _selectSection(String section) {
    Navigator.of(context).pop();
    setState(() {
      _currentView = section;
    });
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

  Widget _buildProductGrid(BuildContext context) {
    final filteredProducts = _currentView == 'Todos'
        ? _allProducts
        : _allProducts.where((p) => p.category == _currentView).toList();

    final cartModel = ChangeNotifierProvider.of<CartModel>(context);

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(8.0),
            child: filteredProducts.isEmpty
                ? Center(
                    child: Text(
                      'No hay productos en la categoría $_currentView.',
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
          );
  }

  // Lógica para determinar el contenido de la pantalla principal
  Widget _buildBody() {
    switch (_currentView) {
      case 'Mi Carrito':
        return CartScreen(
          user: widget.user,
          onOrderPlaced: (status) {
            setState(() {
              _currentView = 'Confirmación';
            });
            // Opcional: mostrar un Snackbar con el estado
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '¡Orden realizada! Pago: $status. Regresando al inicio...',
                ),
                duration: const Duration(seconds: 3),
                backgroundColor: Theme.of(context).primaryColor,
              ),
            );
          },
        );
      case 'Mis Órdenes':
        return UserOrdersScreen(userId: widget.user.email);
      case 'Confirmación':
        // Después de la confirmación, regresamos al inicio en un tiempo
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _currentView == 'Confirmación') {
            setState(() {
              _currentView = 'Tienda (Inicio)';
            });
          }
        });
        return const OrderConfirmationScreen();
      case 'Tienda (Inicio)':
        return _buildHomeContentView(context, widget.user);
      default:
        // Todas las categorías
        return _buildProductGrid(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartModel = ChangeNotifierProvider.of<CartModel>(context);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Theme.of(context).primaryColor,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentView, style: const TextStyle(fontSize: 18)),
            Text(
              'Usuario: ${widget.user.email}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  setState(() {
                    _currentView = 'Mi Carrito';
                  });
                },
              ),
              if (cartModel.totalItemCount > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      cartModel.totalItemCount.toString(),
                      style: const TextStyle(
                        color: Colors.black, // Color negro para contraste
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Botón de ir a órdenes (solo si no estamos en 'Mi Carrito' u 'Órdenes')
          if (_currentView != 'Mi Carrito' && _currentView != 'Mis Órdenes')
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                setState(() {
                  _currentView = 'Mis Órdenes';
                });
              },
            ),
        ],
      ),
      drawer: CustomDrawer(
        user: widget.user,
        categories: _categories,
        currentCategory: _currentView,
        onSelectCategory: (category) {
          setState(() {
            _currentView = category;
          });
          Navigator.of(context).pop(); // Cierra el Drawer
        },
        onLogout: widget.onLogout,
      ),
      body: _buildBody(),
    );
  }
}

// =======================================================================
// 7. WIDGETS REUTILIZABLES
// =======================================================================

// --- Card de Producto para la cuadrícula ---
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
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen del Producto
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  product.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 5.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Cat: ${product.category}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 5),
                Text(
                  '${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(product.price)} c/u',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onAddToCart,
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Añadir', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
}

// --- Item del Carrito de Compras ---
class CartItemTile extends StatelessWidget {
  final CartItem item;
  final CartModel cartModel;

  const CartItemTile({super.key, required this.item, required this.cartModel});

  @override
  Widget build(BuildContext context) {
    final Product product = item.product;
    final totalItemPrice = item.quantity * product.price;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.asset(
            product.imagePath,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.image),
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(product.price)} x ${item.quantity}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón -
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => cartModel.decrementItemQuantity(product),
            ),
            // Cantidad
            Text(
              item.quantity.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            // Botón +
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
              onPressed: () => cartModel.incrementItemQuantity(product),
            ),
            // Total del Item
            Container(
              width: 60,
              alignment: Alignment.centerRight,
              child: Text(
                NumberFormat.currency(
                  symbol: '\$',
                  decimalDigits: 2,
                ).format(totalItemPrice),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Resumen de Orden ---
class OrderSummaryCard extends StatelessWidget {
  final double subtotal;
  final double total;
  final String? discountText;

  const OrderSummaryCard({
    super.key,
    required this.subtotal,
    required this.total,
    this.discountText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Resumen del Pedido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(height: 10),
            _buildSummaryRow('Subtotal:', subtotal, Colors.black87),
            if (discountText != null)
              _buildSummaryRow(discountText!, 0.0, Colors.green),
            const Divider(height: 20),
            _buildSummaryRow(
              'TOTAL A PAGAR:',
              total,
              Theme.of(context).primaryColor,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    Color color, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? color : Colors.black,
            ),
          ),
          Text(
            NumberFormat.currency(
              symbol: '\$',
              decimalDigits: 2,
            ).format(amount),
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Tile de Orden Histórica ---
class OrderTile extends StatelessWidget {
  final Order order;
  final bool isAdminView;

  const OrderTile({super.key, required this.order, this.isAdminView = false});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isPaid = order.status == 'Pagado';
    final statusColor = isPaid ? Colors.green : Colors.amber[700];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: 4,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        leading: Icon(Icons.receipt_long, color: primaryColor, size: 30),
        title: Text(
          'Orden #${order.id.split('-').last}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAdminView)
              Text(
                'Cliente: ${order.userId}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(order.date),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Estado: ${order.status}',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        trailing: Text(
          NumberFormat.currency(
            symbol: '\$',
            decimalDigits: 2,
          ).format(order.total),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: primaryColor,
          ),
        ),
        children: [
          const Divider(),
          ...order.items.map((item) {
            return ListTile(
              title: Text(item.product.name),
              trailing: Text(
                '${item.quantity} x \$${item.product.price.toStringAsFixed(2)}',
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// --- Drawer personalizado ---
class CustomDrawer extends StatelessWidget {
  final User user;
  final List<String> categories;
  final String currentCategory;
  final Function(String) onSelectCategory;
  final VoidCallback onLogout;

  const CustomDrawer({
    super.key,
    required this.user,
    required this.categories,
    required this.currentCategory,
    required this.onSelectCategory,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Drawer(
      child: Column(
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(
              user.isAdmin ? 'Administrador' : user.email,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: user.isAdmin
                ? const Text(
                    'Vista de Administración',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )
                : const Text('Comprador'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                user.isAdmin ? Icons.lock_open : Icons.person,
                color: primaryColor,
                size: 40,
              ),
            ),
            decoration: BoxDecoration(color: primaryColor),
          ),
          // Secciones de Categorías
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == currentCategory;
                return ListTile(
                  title: Text(category),
                  leading: const Icon(Icons.category),
                  selected: isSelected,
                  selectedTileColor: primaryColor.withOpacity(0.1),
                  selectedColor: primaryColor,
                  onTap: () => onSelectCategory(category),
                );
              },
            ),
          ),

          const Divider(),

          // Sección de Órdenes
          ListTile(
            title: const Text('Mis Órdenes'),
            leading: const Icon(Icons.history),
            onTap: () => onSelectCategory('Mis Órdenes'),
          ),

          // Botón de Cerrar Sesión
          ListTile(
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () {
              Navigator.of(context).pop();
              onLogout();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// =======================================================================
// 8. PANTALLAS DE FLUJO DE COMPRA
// =======================================================================

class CartScreen extends StatelessWidget {
  final User user;
  final Function(String) onOrderPlaced;

  const CartScreen({
    super.key,
    required this.user,
    required this.onOrderPlaced,
  });

  void _showCheckoutDialog(BuildContext context, CartModel cartModel) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Finalizar Pedido',
            style: TextStyle(color: Theme.of(context).primaryColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrderSummaryCard(
                subtotal: cartModel.totalCartPrice,
                total: cartModel.totalCartPrice,
              ),
              const SizedBox(height: 20),
              const Text(
                'Selecciona el método de pago:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Simulación de Pedido Fiado
                Navigator.of(dialogContext).pop();
                await ApiService().placeOrder(
                  user,
                  cartModel.items,
                  cartModel.totalCartPrice,
                  'Fiado',
                );
                cartModel.clearCart();
                onOrderPlaced('Fiado');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('Fiado', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              onPressed: () async {
                // Simulación de Pago
                Navigator.of(dialogContext).pop();
                await ApiService().placeOrder(
                  user,
                  cartModel.items,
                  cartModel.totalCartPrice,
                  'Pagado',
                );
                cartModel.clearCart();
                onOrderPlaced('Pagado');
              },
              child: const Text('Pagar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartModel = ChangeNotifierProvider.of<CartModel>(context);

    if (cartModel.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 20),
            const Text(
              'Tu carrito está vacío.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Añade productos de la tienda para empezar a comprar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Lista de Items del Carrito
        Expanded(
          child: ListView.builder(
            itemCount: cartModel.items.length,
            itemBuilder: (context, index) {
              final item = cartModel.items[index];
              return CartItemTile(item: item, cartModel: cartModel);
            },
          ),
        ),
        // Resumen y Botón de Checkout
        OrderSummaryCard(
          subtotal: cartModel.totalCartPrice,
          total: cartModel.totalCartPrice,
          discountText: 'Descuento (0%):',
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            onPressed: () => _showCheckoutDialog(context, cartModel),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('FINALIZAR COMPRA'),
          ),
        ),
      ],
    );
  }
}

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(30),
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 20),
              const Text(
                '¡Orden Realizada con Éxito!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu pedido está siendo procesado.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              // Aquí no se usa un botón de vuelta a Home porque el HomeScreen maneja
              // la navegación de vuelta automáticamente después de un tiempo.
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Regresando al inicio en 3 segundos...',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserOrdersScreen extends StatefulWidget {
  final String userId;

  const UserOrdersScreen({super.key, required this.userId});

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen> {
  final ApiService _apiService = ApiService();
  Future<List<Order>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = _apiService.getUserOrders(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Order>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar órdenes: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 20),
                const Text(
                  'No tienes órdenes registradas.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            // Recarga las órdenes
            _loadOrders();
          },
          child: ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return OrderTile(order: orders[index]);
            },
          ),
        );
      },
    );
  }
}

// =======================================================================
// 9. PANTALLA DE ADMINISTRADOR
// =======================================================================

class AdminScreen extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;
  const AdminScreen({super.key, required this.user, required this.onLogout});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ApiService _apiService = ApiService();
  Future<List<Order>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = _apiService.getAdminOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        automaticallyImplyLeading: false, // Oculta el botón de menú
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: FutureBuilder<List<Order>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar órdenes: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No hay órdenes registradas aún.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data!;
          final totalSales = orders.fold(
            0.0,
            (sum, order) => sum + order.total,
          );

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(12.0),
                elevation: 4,
                color: Theme.of(context).primaryColor.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ventas Totales:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(
                          symbol: '\$',
                          decimalDigits: 2,
                        ).format(totalSales),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _loadOrders();
                  },
                  child: ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return OrderTile(order: orders[index], isAdminView: true);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
