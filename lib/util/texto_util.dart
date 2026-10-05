/// "1 venta", "3 ventas".
String plural(int n, String uno, String varios) =>
    '$n ${n == 1 ? uno : varios}';
