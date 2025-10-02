// Proyecto: tienda_online_reina
// Archivo principal: main.dart
// Descripción: Aplicación con persistencia de órdenes usando shared_preferences.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:collection/collection.dart'; 
import 'package:intl/intl.dart'; 
import 'dart:convert'; // Necesario para codificar y decodificar JSON
import 'package:shared_preferences/shared_preferences.dart'; // Persistencia de datos

// =======================================================================
// 1. MODELOS DE DATOS (CON JSON SERIALIZATION)
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
  factory CartItem.fromJson(Map<String, dynamic> json, List<Product> availableProducts) {
    final productId = json['product_id'];
    final product = availableProducts.firstWhere((p) => p.id == productId);
    return CartItem(
      product: product,
      quantity: json['quantity'],
    );
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
    'items': items.map((i) => i.toJson()).toList(), // Guarda solo IDs y cantidad
    'total': total,
    'status': status,
    'date': date.toIso8601String(),
  };

  // Crear desde JSON (para cargar)
  factory Order.fromJson(Map<String, dynamic> json, List<Product> availableProducts) {
    // Reconstruir la lista de CartItems
    final List<dynamic> itemsJson = json['items'];
    final items = itemsJson.map((i) => CartItem.fromJson(i, availableProducts)).toList();
    
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
    Product(id: 'P01', name: 'Pollo Entero', price: 6.50, imagePath: 'assets/images/pollo_entero.jpg', category: 'Carnes'),
    Product(id: 'P02', name: 'Carne de Cerdo', price: 4.80, imagePath: 'assets/images/carne_chancho.jpg', category: 'Carnes'),
    Product(id: 'P03', name: 'Carne de Res', price: 5.20, imagePath: 'assets/images/carne_vaca.jpg', category: 'Carnes'),
    Product(id: 'P04', name: 'Pescado Fresco', price: 7.00, imagePath: 'assets/images/pescado.jpg', category: 'Carnes'),
    Product(id: 'P05', name: 'Salchichas Paquete', price: 2.50, imagePath: 'assets/images/salchichas.jpg', category: 'Embutidos'),
    Product(id: 'P06', name: 'Costal de Arroz 5kg', price: 8.99, imagePath: 'assets/images/costal_arroz.jpg', category: 'Productos Básicos'),
    Product(id: 'P07', name: 'Cubeta de Huevos', price: 3.50, imagePath: 'assets/images/cubeta_huevos.jpg', category: 'Productos Básicos'),
    Product(id: 'P08', name: 'Leche Vita 1L', price: 0.95, imagePath: 'assets/images/leche_vita.jpg', category: 'Lácteos'),
    Product(id: 'P09', name: 'Yogurt Toni 1L', price: 1.80, imagePath: 'assets/images/yogurt_toni.jpg', category: 'Lácteos'),
    Product(id: 'P10', name: 'Fideos Don Victorio', price: 0.75, imagePath: 'assets/images/fideos_donvictorio.jpg', category: 'Harinas'),
    Product(id: 'P11', name: 'Harina de Trigo 1kg', price: 1.20, imagePath: 'assets/images/harina.jpg', category: 'Harinas'),
    Product(id: 'P12', name: 'Pan Fresco', price: 1.50, imagePath: 'assets/images/pan.jpg', category: 'Harinas'),
    Product(id: 'P13', name: 'Rapiditos Paquete', price: 1.10, imagePath: 'assets/images/rapiditos.jpg', category: 'Harinas'),
    Product(id: 'P14', name: 'Panchitos Bolsa', price: 0.50, imagePath: 'assets/images/panchitos.jpg', category: 'Golosinas'),
    Product(id: 'P15', name: 'Barra de Chocolate', price: 0.80, imagePath: 'assets/images/chocolate.jpg', category: 'Golosinas'),
    Product(id: 'P16', name: 'Chupetes x10', price: 1.00, imagePath: 'assets/images/chupetes.jpg', category: 'Golosinas'),
    Product(id: 'P17', name: 'Gomitas Paquete', price: 0.60, imagePath: 'assets/images/gomitas.jpg', category: 'Golosinas'),
    Product(id: 'P18', name: 'Botella de Agua 1L', price: 0.75, imagePath: 'assets/images/agua.jpg', category: 'Bebidas'),
    Product(id: 'P19', name: 'Coca Cola 2L', price: 2.25, imagePath: 'assets/images/coca_cola.jpg', category: 'Bebidas'),
    Product(id: 'P20', name: 'Sprite 2L', price: 2.10, imagePath: 'assets/images/sprite.jpg', category: 'Bebidas'),
    Product(id: 'P21', name: 'Fiora Vanti 1.5L', price: 1.85, imagePath: 'assets/images/fiora_vanti.jpg', category: 'Bebidas'),
    Product(id: 'P22', name: 'Inca Kola 2L', price: 2.30, imagePath: 'assets/images/inca_cola.jpg', category: 'Bebidas'),
    Product(id: 'P23', name: 'Gatorade Naranja', price: 1.50, imagePath: 'assets/images/gatorade.jpg', category: 'Bebidas'),
    Product(id: 'P24', name: 'Vive Cien', price: 0.70, imagePath: 'assets/images/vive_cien.jpg', category: 'Bebidas'),
    Product(id: 'P25', name: '220V Lata', price: 0.65, imagePath: 'assets/images/220v.jpg', category: 'Bebidas'),
    Product(id: 'P26', name: 'Vino Tinto Botella', price: 12.00, imagePath: 'assets/images/vino.jpg', category: 'Alcohol'),
    Product(id: 'P27', name: 'Cerveza Pilsener Lata', price: 1.25, imagePath: 'assets/images/pilsener.jpg', category: 'Alcohol'),
    Product(id: 'P28', name: 'Cerveza Club Lata', price: 1.35, imagePath: 'assets/images/club_cerveza.jpg', category: 'Alcohol'),
    Product(id: 'P29', name: 'Cerveza Corona', price: 2.50, imagePath: 'assets/images/corona.jpg', category: 'Alcohol'),
    Product(id: 'P30', name: 'Ron Cubata', price: 15.00, imagePath: 'assets/images/cubata.jpg', category: 'Alcohol'),
    Product(id: 'P31', name: 'Vodka Switch', price: 10.50, imagePath: 'assets/images/switch.jpg', category: 'Alcohol'),
    Product(id: 'P32', name: 'Caja de Lark', price: 4.00, imagePath: 'assets/images/lark.jpg', category: 'Cigarrillos'),
    Product(id: 'P33', name: 'Caja de Elephant', price: 4.20, imagePath: 'assets/images/elephant.jpg', category: 'Cigarrillos'),
    Product(id: 'P34', name: 'Caja de Carnival', price: 3.80, imagePath: 'assets/images/carnival.jpg', category: 'Cigarrillos'),
  ];
  
  // Clave de almacenamiento
  static const String _ordersKey = 'tienda_reina_orders';

  // --- MÉTODOS DE PERSISTENCIA ---
  
  // Carga las órdenes guardadas al iniciar la aplicación
  static Future<void> loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersJsonString = prefs.getString(_ordersKey);
    
    if (ordersJsonString != null) {
      final List<dynamic> ordersList = jsonDecode(ordersJsonString);
      _orders = ordersList.map((json) => Order.fromJson(json, _products)).toList();
    } else {
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
  Future<String?> register({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 500)); 
    if (_users.any((u) => u.email == email)) {
      return 'El email ya está registrado.';
    }
    _users.add(User(email: email, password: password));
    return null; 
  }

  Future<User?> login({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 500)); 
    return _users.firstWhereOrNull((u) => u.email == email && u.password == password);
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

  Future<void> placeOrder(User user, List<CartItem> items, double total, String status) async {
    await Future.delayed(const Duration(seconds: 1));
    
    final orderId = '${DateTime.now().millisecondsSinceEpoch}-${_orders.length + 1}';
    
    _orders.add(Order(
      id: orderId,
      userId: user.email,
      items: items.map((item) => CartItem(product: item.product, quantity: item.quantity)).toList(), 
      total: total,
      status: status,
      date: DateTime.now(),
    ));
    
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

  double get totalCartPrice {
    return _items.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
  }

  void addItem(Product product) {
    final existingItem = _items.firstWhereOrNull((item) => item.product.id == product.id);

    if (existingItem != null) {
      existingItem.quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeItem(Product product) {
    final existingItem = _items.firstWhereOrNull((item) => item.product.id == product.id);

    if (existingItem != null) {
      if (existingItem.quantity > 1) {
        existingItem.quantity--;
      } else {
        _items.removeWhere((item) => item.product.id == product.id); 
      }
      notifyListeners();
    }
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
  bool updateShouldNotify(ChangeNotifierProvider oldWidget) => oldWidget.value != value;

  static T of<T extends ChangeNotifier>(BuildContext context, {bool listen = true}) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<ChangeNotifierProvider<T>>()
        : context.getElementForInheritedWidgetOfExactType<ChangeNotifierProvider<T>>()?.widget as ChangeNotifierProvider<T>?;
    
    if (provider == null) {
      throw FlutterError('No se encontró un ChangeNotifierProvider de tipo $T en el árbol.');
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
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
        scaffoldBackgroundColor: pastelPink.withOpacity(0.3), 
        cardTheme: CardThemeData( 
          color: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: wineRed, secondary: pastelPink),
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
      String? error = await _apiService.register(email: email, password: password);
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
              return Container(color: Colors.grey, child: const Center(child: Text('Fondo no encontrado o ruta incorrecta.', style: TextStyle(color: Colors.white))));
            },
          ),
          
          // 2. Overlay Oscuro Semi-transparente
          Container(
            color: Colors.black.withOpacity(0.6),
          ),

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
                        _isRegistering ? 'Crear Cuenta' : 'Bienvenido a Tienda Reina',
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
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.person)),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock)),
                      ),
                      const SizedBox(height: 25),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _submitAuth,
                              child: Text(_isRegistering ? 'REGISTRAR' : 'INGRESAR'),
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
                          _isRegistering ? '¿Ya tienes cuenta? Inicia Sesión' : '¿No tienes cuenta? Regístrate aquí',
                          style: TextStyle(color: Theme.of(context).primaryColor),
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
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          },
        ),
        
        Container(
          color: Colors.black.withOpacity(0.5),
        ),
        
        Center(
          child: Card(
            color: Colors.white.withOpacity(0.85),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            elevation: 10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                    user.email,
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
                ? Center(child: Text('No hay productos en la categoría $_currentView.'))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
            const Text('Tienda Reina', style: TextStyle(fontSize: 18)),
            Text(
              'Usuario: ${widget.user.email}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      
      body: _currentView == 'Tienda (Inicio)'
          ? _buildHomeContentView(context, widget.user)
          : _buildProductGrid(context),
            
      floatingActionButton: Stack(
        alignment: Alignment.topRight,
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            heroTag: "cartFab", 
            child: const Icon(Icons.shopping_cart),
          ),
          if (cartModel.totalItemCount > 0)
            Positioned(
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(
                  minWidth: 22,
                  minHeight: 22,
                ),
                child: Text(
                  '${cartModel.totalItemCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDrawer(BuildContext context) {
    final List<String> allSections = ['Tienda (Inicio)', ..._categories];

    return Drawer(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor, 
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor, 
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MENÚ', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(widget.user.email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: allSections.length + 1, 
                itemBuilder: (context, index) {
                  if (index < allSections.length) {
                    final section = allSections[index];
                    final isHome = section == 'Tienda (Inicio)';
                    return ListTile(
                      leading: Icon(
                        isHome ? Icons.home_rounded : Icons.category,
                        color: section == _currentView ? Theme.of(context).primaryColor : Colors.black54,
                      ),
                      title: Text(
                        section,
                        style: TextStyle(
                          fontWeight: section == _currentView ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: section == _currentView,
                      onTap: () => _selectSection(section),
                    );
                  } else {
                    // Historial de Órdenes
                    return ListTile(
                      leading: Icon(Icons.receipt, color: Theme.of(context).primaryColor),
                      title: const Text('Mi Historial de Órdenes'),
                      onTap: () {
                        Navigator.of(context).pop(); 
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => OrderHistoryScreen(user: widget.user)),
                        );
                      },
                    );
                  }
                },
              ),
            ),
            
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Cerrar Sesión'),
              onTap: () {
                Navigator.of(context).pop(); 
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthenticationWrapper()),
                  (Route<dynamic> route) => false,
                );
                widget.onLogout(); 
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToCart;

  const ProductCard({super.key, required this.product, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  product.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      alignment: Alignment.center,
                      child: const Icon(Icons.fastfood, size: 50, color: Colors.black54),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${product.category}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                
                InkWell(
                  onTap: onAddToCart,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================================
// 7. PANTALLAS DE CARRITO Y DETALLE DE ORDEN
// =======================================================================

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  User? _getCurrentUser(BuildContext context) {
    final authState = context.findAncestorStateOfType<_AuthenticationWrapperState>();
    return authState?.currentUser;
  }

  void _showPaymentDialog(BuildContext context, CartModel cartModel) {
    if (cartModel.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El carrito está vacío.')),
      );
      return;
    }

    final ApiService apiService = ApiService();
    final User? currentUser = _getCurrentUser(context);
    
    // Controladores de texto para simular la captura de datos de pago
    final TextEditingController cardController = TextEditingController();
    final TextEditingController accountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Confirmar Compra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total a pagar: \$${cartModel.totalCartPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text('Opciones de Pago Electrónico (Simulado):', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                // Simulación de campo de Tarjeta
                TextField(
                  controller: cardController,
                  decoration: const InputDecoration(
                    labelText: 'Nº Tarjeta Crédito/Débito',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                // Simulación de campo para Transferencia / Deuna
                TextField(
                  controller: accountController,
                  decoration: const InputDecoration(
                    labelText: 'Nº Cuenta para Transferencia / Deuna',
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Nota: Aunque ingreses datos aquí, el pago se simula como Pagado/Fiado y SÍ se registrará en tu historial.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); 
              },
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            
            ElevatedButton(
              onPressed: () async {
                if (currentUser != null) {
                  await apiService.placeOrder(currentUser, cartModel.items, cartModel.totalCartPrice, 'Fiado');
                  cartModel.clearCart();
                  Navigator.of(context).pop(); 
                  Navigator.of(context).pop(); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Compra FIADA registrada y guardada!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange, 
                foregroundColor: Colors.white,
              ),
              child: const Text('FIAR (Crédito)'),
            ),
            
            ElevatedButton(
              onPressed: () async {
                if (currentUser != null) {
                  await apiService.placeOrder(currentUser, cartModel.items, cartModel.totalCartPrice, 'Pagado');
                  cartModel.clearCart();
                  Navigator.of(context).pop(); 
                  Navigator.of(context).pop(); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Pago realizado y guardado!')),
                  );
                }
              },
              child: const Text('PAGAR'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartModel = ChangeNotifierProvider.of<CartModel>(context, listen: true);
    final total = cartModel.totalCartPrice;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Carrito de Compras')),
      body: cartModel.items.isEmpty
          ? Center(
              child: Text(
                'El carrito está vacío.',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartModel.items.length,
                    itemBuilder: (context, index) {
                      final item = cartModel.items[index];
                      return CartItemTile(item: item, cartModel: cartModel);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () => _showPaymentDialog(context, cartModel),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                        child: const Text('Proceder a Confirmar Compra'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class CartItemTile extends StatelessWidget {
  final CartItem item;
  final CartModel cartModel;

  const CartItemTile({super.key, required this.item, required this.cartModel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.asset(
            item.product.imagePath,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
          ),
        ),
        title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('\$${item.product.price.toStringAsFixed(2)} x ${item.quantity}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => cartModel.removeItem(item.product),
            ),
            Text('${item.quantity}'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
              onPressed: () => cartModel.addItem(item.product),
            ),
          ],
        ),
      ),
    );
  }
}


class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isFiado = order.status == 'Fiado';
    final statusColor = isFiado ? Colors.deepOrange : Colors.green;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle de Orden (${order.status})'),
        backgroundColor: statusColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente: ${order.userId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fecha:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(DateFormat('dd/MM/yyyy HH:mm').format(order.date.toLocal())),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                        Text('\$${order.total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: statusColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Productos Comprados:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            
            Expanded(
              child: ListView.builder(
                itemCount: order.items.length,
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.product.name),
                    subtitle: Text('Precio: \$${item.product.price.toStringAsFixed(2)}'),
                    trailing: Text(
                      '${item.quantity} x \$${item.product.price.toStringAsFixed(2)} = \$${(item.product.price * item.quantity).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class OrderHistoryScreen extends StatefulWidget {
  final User user;
  const OrderHistoryScreen({super.key, required this.user});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final ApiService _apiService = ApiService();
  Future<List<Order>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }
  
  Future<void> _loadOrders() async {
    // Llama a la carga de órdenes que ahora también utiliza persistencia
    setState(() {
      _ordersFuture = _apiService.getUserOrders(widget.user.email);
    });
  }
  
  void _viewOrderDetail(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Historial de Órdenes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders, // Recarga la lista desde la persistencia
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
            return Center(child: Text('Error al cargar órdenes: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No has realizado ninguna compra aún.',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            );
          }
          
          final orders = snapshot.data!;
          // Cálculo de saldo fiado pendiente
          final totalFiado = orders
              .where((o) => o.status == 'Fiado')
              .fold(0.0, (sum, o) => sum + o.total);

          return Column(
            children: [
              Card(
                color: totalFiado > 0 ? Colors.red.shade100 : Colors.green.shade100,
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: Icon(
                    totalFiado > 0 ? Icons.warning : Icons.check_circle, 
                    color: totalFiado > 0 ? Colors.red : Colors.green,
                  ),
                  title: Text(
                    'Saldo Fiado Pendiente:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: totalFiado > 0 ? Colors.red : Colors.black87),
                  ),
                  trailing: Text(
                    '\$${totalFiado.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: totalFiado > 0 ? Colors.red : Colors.green
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16.0, top: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Últimas Órdenes:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final isFiado = order.status == 'Fiado';
                    final statusColor = isFiado ? Colors.deepOrange : Colors.green;
                    
                    return Card(
                      color: isFiado ? Colors.orange.shade50 : Colors.white,
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(
                          isFiado ? Icons.credit_card_off : Icons.check_circle,
                          color: statusColor,
                        ),
                        title: Text(
                          'Orden #${orders.length - index} | Total: \$${order.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isFiado ? Colors.deepOrange : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          'Estado: ${order.status} | ${DateFormat('dd/MM/yyyy').format(order.date.toLocal())}',
                          style: TextStyle(color: statusColor),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _viewOrderDetail(order), 
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
  
  Future<void> _loadOrders() async {
    // Carga las órdenes persistidas
    setState(() {
      _ordersFuture = _apiService.getAdminOrders();
    });
  }

  void _viewOrderDetail(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADMINISTRADOR - Órdenes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders, // Recarga la lista desde la persistencia
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: widget.onLogout,
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
            return Center(child: Text('Error al cargar órdenes: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No hay órdenes registradas aún.',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            );
          }
          
          final orders = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final isFiado = order.status == 'Fiado';
              final statusColor = isFiado ? Colors.deepOrange : Colors.green;
              
              return Card(
                color: isFiado ? Colors.orange.shade100 : Colors.white,
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  leading: Icon(
                    isFiado ? Icons.credit_card_off : Icons.check_circle,
                    color: statusColor,
                  ),
                  title: Text(
                    'Orden #${orders.length - index} | Cliente: ${order.userId}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isFiado ? Colors.deepOrange : Colors.black,
                    ),
                  ),
                  subtitle: Text('Total: \$${order.total.toStringAsFixed(2)} | Estado: ${order.status}'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _viewOrderDetail(order), 
                ),
              );
            },
          );
        },
      ),
    );
  }
}