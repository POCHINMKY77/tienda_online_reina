import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

// =======================================================================
// CONFIGURACIÓN DE SUPABASE
// =======================================================================
class SupabaseConfig {
  // REEMPLAZA ESTOS VALORES CON TUS CREDENCIALES DE SUPABASE
  static const String supabaseUrl = 'https://nytegffrdhywrwcxjkih.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55dGVnZmZyZGh5d3J3Y3hqa2loIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE3ODg4OTAsImV4cCI6MjA3NzM2NDg5MH0.-hNJ4xbILf0fUVNpe16k6QuyrLioSsi_oVdvDovCO8E';
}

// =======================================================================
// 1. MODELOS DE DATOS
// =======================================================================

class User {
  final String email;
  final String password;
  final bool isAdmin;
  User({required this.email, required this.password, this.isAdmin = false});

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'is_admin': isAdmin,
  };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'],
      password: json['password'],
      isAdmin: json['is_admin'] ?? false,
    );
  }
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

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: json['price'].toDouble(),
      imagePath: json['image_path'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'image_path': imagePath,
    'category': category,
  };
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});

  Map<String, dynamic> toJson() => {
    'product_id': product.id,
    'quantity': quantity,
  };

  factory CartItem.fromJson(
    Map<String, dynamic> json,
    List<Product> availableProducts,
  ) {
    final productId = json['product_id'];
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
  final String status;
  final DateTime date;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.status,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    // Usar jsonEncode en la capa de la API, no en el modelo
    'items': items.map((i) => i.toJson()).toList(),
    'total': total,
    'status': status,
    'date': date.toIso8601String(),
  };

  factory Order.fromJson(
    Map<String, dynamic> json,
    List<Product> availableProducts,
  ) {
    // Si la columna 'items' en Supabase es un JSONB, el valor ya es un List<dynamic>
    // Si es un String, se requiere jsonDecode
    final List<dynamic> itemsJson = (json['items'] is String)
        ? jsonDecode(json['items'])
        : json['items'];

    final items = itemsJson
        .map((i) => CartItem.fromJson(i, availableProducts))
        .toList();

    return Order(
      id: json['id'],
      userId: json['user_id'],
      items: items,
      total: json['total'].toDouble(),
      status: json['status'],
      date: DateTime.parse(json['date']),
    );
  }
}

// =======================================================================
// 2. SERVICIO DE API CON SUPABASE
// =======================================================================

class ApiService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lista de productos predefinidos (se insertarán en Supabase si no existen)
  static final List<Product> _defaultProducts = [
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

  // Inicializar productos en Supabase
  Future<void> initializeProducts() async {
    try {
      final response = await _supabase.from('products').select().limit(1);
      // Usar la propiedad isEmpty del resultado de la consulta.
      if (response.isEmpty) {
        for (var product in _defaultProducts) {
          // El método insert requiere un List<Map> o un Map
          await _supabase.from('products').insert(product.toJson());
        }
        debugPrint('Productos inicializados en Supabase');
      }
    } catch (e) {
      debugPrint('Error al inicializar productos: $e');
    }
  }

  // Autenticación
  Future<String?> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('email', email);
      if (response.isNotEmpty) {
        return 'El email ya está registrado.';
      }

      await _supabase.from('users').insert({
        'email': email,
        'password': password,
        'is_admin': false,
      });

      return null;
    } catch (e) {
      debugPrint('Error en registro: $e');
      return 'Error al registrar usuario';
    }
  }

  Future<User?> login({required String email, required String password}) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .eq('password', password)
          .single();

      return User.fromJson(response);
    } catch (e) {
      debugPrint('Error en login: $e');
      return null;
    }
  }

  // Productos
  Future<List<Product>> getProducts() async {
    try {
      final response = await _supabase.from('products').select();
      return response.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error al obtener productos: $e');
      return [];
    }
  }

  Future<List<String>> getCategories() async {
    try {
      final products = await getProducts();
      return products.map((p) => p.category).toSet().toList();
    } catch (e) {
      debugPrint('Error al obtener categorías: $e');
      return [];
    }
  }

  // Órdenes
  Future<void> placeOrder(
    User user,
    List<CartItem> items,
    double total,
    String status,
  ) async {
    try {
      final orderId = '${DateTime.now().millisecondsSinceEpoch}';

      await _supabase.from('orders').insert({
        'id': orderId,
        'user_id': user.email,
        // Almacena como JSON string si la columna es TEXT/VARCHAR, o List<Map> si es JSONB
        'items': jsonEncode(items.map((i) => i.toJson()).toList()),
        'total': total,
        'status': status,
        'date': DateTime.now().toIso8601String(),
      });

      debugPrint('Orden creada exitosamente');
    } catch (e) {
      debugPrint('Error al crear orden: $e');
      throw Exception('Error al procesar orden');
    }
  }

  Future<List<Order>> getAdminOrders() async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .order('date', ascending: false);

      final products = await getProducts();
      return response.map((json) => Order.fromJson(json, products)).toList();
    } catch (e) {
      debugPrint('Error al obtener órdenes admin: $e');
      return [];
    }
  }

  Future<List<Order>> getUserOrders(String userId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      final products = await getProducts();
      return response.map((json) => Order.fromJson(json, products)).toList();
    } catch (e) {
      debugPrint('Error al obtener órdenes de usuario: $e');
      return [];
    }
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
    return _items.fold(
      0.0,
      (sum, item) => sum + (item.product.price * item.quantity),
    );
  }

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

  void incrementItemQuantity(Product product) {
    final existingItem = _items.firstWhereOrNull(
      (item) => item.product.id == product.id,
    );
    if (existingItem != null) {
      existingItem.quantity++;
      notifyListeners();
    }
  }

  void decrementItemQuantity(Product product) {
    final existingItem = _items.firstWhereOrNull(
      (item) => item.product.id == product.id,
    );

    if (existingItem != null) {
      if (existingItem.quantity > 1) {
        existingItem.quantity--;
      } else {
        _items.removeWhere((item) => item.product.id == product.id);
      }
      notifyListeners();
    }
  }

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

class ChangeNotifierProvider<T extends ChangeNotifier> extends InheritedWidget {
  final T value;

  const ChangeNotifierProvider({
    super.key,
    required this.value,
    required super.child,
  });

  // Simplificamos la lógica de actualización
  @override
  bool updateShouldNotify(covariant ChangeNotifierProvider<T> oldWidget) =>
      oldWidget.value != value;

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Inicializar productos en la base de datos
  final apiService = ApiService();
  await apiService.initializeProducts();

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
    // Definición de colores
    final Color wineRed = const Color(0xFFB71C1C);
    final Color pastelPink = const Color(0xFFF8C8DC);

    return MaterialApp(
      title: 'Tienda Online Reina',
      debugShowCheckedModeBanner: false,

      // ✅ Todo el tema debe estar dentro de este constructor
      theme: ThemeData(
        // Uso de Material 3 recomendado
        useMaterial3: true,
        fontFamily: 'Inter',
        // Nota: primaryColor está obsoleto, es mejor confiar en ColorScheme
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

        // 1. ✅ CARD THEME: CardThemeData es correcto dentro de ThemeData.
        cardTheme: CardThemeData(
          clipBehavior: Clip.antiAlias,
          color: Colors.white,
          // La constante 'const' debe ir al inicio si es posible
          shadowColor: Colors.grey.shade500,
          elevation: 4.0,
          margin: const EdgeInsets.all(8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),

        // 2. ✅ INPUT DECORATION THEME:
        //    Los parámetros de borde deben ir DENTRO de OutlineInputBorder.
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10),
            ), // Parámetro del borde
            borderSide: BorderSide.none, // Parámetro del borde
          ),
          labelStyle: TextStyle(color: Colors.blue),
        ),

        // 3. COLOR SCHEME:
        colorScheme: ColorScheme.fromSeed(
          seedColor: wineRed,
          // secondary es la propiedad para el color secundario
          secondary: pastelPink,
        ),
      ), // ✅ Cierre CORRECTO de ThemeData
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
      String? error = await _apiService.register(
        email: email,
        password: password,
      );
      if (error == null) {
        // CORRECCIÓN: Si el registro es exitoso, intenta loguear inmediatamente
        final user = await _apiService.login(email: email, password: password);
        if (user != null) {
          widget.onLoginSuccess(user);
        } else {
          setState(
            () => _errorMessage =
                'Registro exitoso, pero falló el inicio de sesión.',
          );
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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
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
          Container(color: Colors.black.withOpacity(0.6)),
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
// 6. PANTALLA PRINCIPAL DE USUARIO (HOME)
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
  String _currentCategory = 'Todos'; // Estado para la categoría seleccionada

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
    Navigator.of(context).pop(); // Cierra el Drawer
    setState(() {
      _currentView = section;
      if (_categories.contains(section)) {
        _currentCategory = section;
        _currentView =
            'Productos'; // Cambia la vista si se selecciona una categoría
      }
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
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _selectSection('Productos'),
                    icon: const Icon(Icons.store),
                    label: const Text('Ir a la Tienda'),
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
    final filteredProducts = _currentCategory == 'Todos'
        ? _allProducts
        : _allProducts.where((p) => p.category == _currentCategory).toList();

    final cartModel = ChangeNotifierProvider.of<CartModel>(context);

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(8.0),
            child: filteredProducts.isEmpty
                ? Center(
                    child: Text(
                      'No hay productos en la categoría $_currentCategory.',
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

  Widget _buildBody() {
    switch (_currentView) {
      case 'Mi Carrito':
        return CartScreen(
          user: widget.user,
          onOrderPlaced: (status) {
            ChangeNotifierProvider.of<CartModel>(
              context,
              listen: false,
            ).clearCart(); // Limpiar carrito
            setState(() {
              _currentView = 'Confirmación';
            });
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
        // CORRECCIÓN: Usamos Future.delayed para volver al Home después de la confirmación
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
      case 'Productos': // Muestra la cuadrícula de productos
      default:
        return _buildProductGrid(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartModel = ChangeNotifierProvider.of<CartModel>(context);

    // Se agrega el Drawer para la navegación
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentView == 'Productos'
                  ? 'Catálogo: $_currentCategory'
                  : _currentView,
              style: const TextStyle(fontSize: 18),
            ),
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
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${cartModel.totalItemCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.store, color: Colors.white, size: 40),
                  const Text(
                    'Tienda Reina',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  Text(
                    widget.user.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              onTap: () => _selectSection('Tienda (Inicio)'),
            ),
            ExpansionTile(
              leading: const Icon(Icons.category),
              title: const Text('Productos por Categoría'),
              initiallyExpanded: _currentView == 'Productos',
              children: _categories.map((category) {
                return ListTile(
                  title: Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(category),
                  ),
                  selected:
                      _currentCategory == category &&
                      _currentView == 'Productos',
                  onTap: () {
                    setState(() {
                      _currentCategory = category;
                      _currentView = 'Productos';
                    });
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Mi Carrito'),
              onTap: () => _selectSection('Mi Carrito'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Mis Órdenes'),
              onTap: () => _selectSection('Mis Órdenes'),
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
      ),
      body: _buildBody(),
    );
  }
}

// =======================================================================
// 7. WIDGET DE TARJETA DE PRODUCTO
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
                      child: Text(
                        '${product.name}\n(Img no encontrada)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                // CORRECCIÓN del error original de sintaxis en el string interpolation
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
                      // Se usan los estilos predefinidos en ThemeData
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

// =======================================================================
// 8. PANTALLA DE CARRITO (CART)
// =======================================================================

class CartScreen extends StatelessWidget {
  final User user;
  final Function(String status) onOrderPlaced;

  const CartScreen({
    super.key,
    required this.user,
    required this.onOrderPlaced,
  });

  void _showCheckoutSheet(BuildContext context, CartModel cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return CheckoutSheet(
          cart: cart,
          user: user,
          onOrderPlaced: onOrderPlaced,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer/Selector (simulado con listen: true en of) para escuchar cambios
    final cartModel = ChangeNotifierProvider.of<CartModel>(context);

    return cartModel.items.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_basket, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('Tu carrito está vacío.', style: TextStyle(fontSize: 18)),
              ],
            ),
          )
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: cartModel.items.length,
                  itemBuilder: (context, index) {
                    final item = cartModel.items[index];
                    return _CartItemTile(cartItem: item, cartModel: cartModel);
                  },
                ),
              ),
              Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
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
                            NumberFormat.currency(
                              symbol: '\$',
                              decimalDigits: 2,
                            ).format(cartModel.totalCartPrice),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showCheckoutSheet(context, cartModel),
                          icon: const Icon(Icons.payment),
                          label: const Text('Proceder a Pagar'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem cartItem;
  final CartModel cartModel;

  const _CartItemTile({required this.cartItem, required this.cartModel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  cartItem.product.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    NumberFormat.currency(
                      symbol: '\$',
                      decimalDigits: 2,
                    ).format(cartItem.product.price),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () =>
                      cartModel.decrementItemQuantity(cartItem.product),
                ),
                Text(
                  '${cartItem.quantity}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () =>
                      cartModel.incrementItemQuantity(cartItem.product),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => cartModel.removeProduct(cartItem.product),
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
// 9. CHECKOUT / PROCESO DE PAGO
// =======================================================================

class CheckoutSheet extends StatefulWidget {
  final CartModel cart;
  final User user;
  final Function(String status) onOrderPlaced;

  const CheckoutSheet({
    super.key,
    required this.cart,
    required this.user,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  String _paymentMethod = 'Efectivo';
  bool _isProcessing = false;

  Future<void> _placeOrder() async {
    setState(() => _isProcessing = true);
    final apiService = ApiService();
    try {
      await apiService.placeOrder(
        widget.user,
        widget.cart.items,
        widget.cart.totalCartPrice,
        _paymentMethod,
      );
      Navigator.of(context).pop(); // Cierra el modal
      widget.onOrderPlaced(_paymentMethod);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al procesar la orden. Intente de nuevo.'),
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de Pago',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total a Pagar:', style: TextStyle(fontSize: 18)),
              Text(
                NumberFormat.currency(
                  symbol: '\$',
                  decimalDigits: 2,
                ).format(widget.cart.totalCartPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Método de Pago:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: const Text('Efectivo'),
            leading: Radio<String>(
              value: 'Efectivo',
              groupValue: _paymentMethod,
              onChanged: (String? value) {
                setState(() => _paymentMethod = value!);
              },
            ),
          ),
          ListTile(
            title: const Text('Tarjeta de Crédito/Débito'),
            leading: Radio<String>(
              value: 'Tarjeta',
              groupValue: _paymentMethod,
              onChanged: (String? value) {
                setState(() => _paymentMethod = value!);
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _isProcessing
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _placeOrder,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmar Pedido'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// 10. PANTALLA DE ÓRDENES DE USUARIO
// =======================================================================

class UserOrdersScreen extends StatefulWidget {
  final String userId;
  const UserOrdersScreen({super.key, required this.userId});

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen> {
  late Future<List<Order>> _ordersFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _ordersFuture = _apiService.getUserOrders(widget.userId);
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
          return const Center(
            child: Text(
              'Aún no tienes órdenes.',
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        final orders = snapshot.data!;
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: ExpansionTile(
                title: Text(
                  'Orden #${order.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Total: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(order.total)} | Estado: ${order.status}',
                ),
                children: order.items.map((item) {
                  return ListTile(
                    contentPadding: const EdgeInsets.only(left: 30, right: 16),
                    title: Text(item.product.name),
                    trailing: Text('x${item.quantity}'),
                    subtitle: Text(
                      'Precio: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(item.product.price)}',
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
}

// =======================================================================
// 11. PANTALLA DE CONFIRMACIÓN DE ORDEN
// =======================================================================

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
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                '¡Orden Confirmada!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu pedido ha sido procesado con éxito. ¡Gracias por tu compra!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                'Volviendo a la tienda en 3 segundos...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================================
// 12. PANTALLAS DE ADMINISTRADOR
// =======================================================================

class AdminScreen extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;
  const AdminScreen({super.key, required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Administración'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Órdenes', icon: Icon(Icons.receipt)),
              Tab(text: 'Productos', icon: Icon(Icons.inventory)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: onLogout,
              tooltip: 'Cerrar Sesión',
            ),
          ],
        ),
        body: const TabBarView(
          children: [AdminOrdersScreen(), AdminProductsScreen()],
        ),
      ),
    );
  }
}

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late Future<List<Order>> _ordersFuture;
  final ApiService _apiService = ApiService();

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
          return const Center(child: Text('No hay órdenes pendientes.'));
        }

        final orders = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            _loadOrders();
            await _ordersFuture;
          },
          child: ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ExpansionTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: Text(
                    'Orden #${order.id.substring(order.id.length - 4)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Usuario: ${order.userId}\nTotal: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(order.total)} | Estado: ${order.status}',
                  ),
                  children: order.items.map((item) {
                    return ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 30,
                        right: 16,
                      ),
                      title: Text(item.product.name),
                      trailing: Text('x${item.quantity}'),
                      subtitle: Text(
                        'Precio: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(item.product.price)}',
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Para simplificar, esta pantalla solo mostrará la lista de productos por defecto.
    // La funcionalidad de "Administrar" (agregar/editar/eliminar) implicaría un manejo
    // de estado más complejo y lógica de formularios que excede el objetivo de esta corrección.
    final products = ApiService._defaultProducts;

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ListTile(
          leading: SizedBox(
            width: 50,
            height: 50,
            child: Image.asset(
              product.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: Colors.grey),
            ),
          ),
          title: Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Categoría: ${product.category} | Precio: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(product.price)}',
          ),
          trailing: const Icon(
            Icons.edit,
            color: Colors.blue,
          ), // Placeholder para la acción de editar
          onTap: () {
            // Acción de editar/ver detalles
          },
        );
      },
    );
  }
}
