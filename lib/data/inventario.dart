/// Un conteo inicial (al activar el control) o un ajuste por conteo físico.
enum TipoConteo { inicial, ajuste }

/// Un pedido a un proveedor: espera la mercancía, ya llegó o se anuló.
enum EstadoPedido { porLlegar, recibido, anulado }
