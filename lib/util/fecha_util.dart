DateTime inicioDelDia(DateTime dia) => DateTime(dia.year, dia.month, dia.day);

DateTime finDelDia(DateTime dia) =>
    DateTime(dia.year, dia.month, dia.day, 23, 59, 59, 999);
