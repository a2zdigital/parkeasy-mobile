final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isOptionalProfileEmailValid(String email) =>
    email.isEmpty || (email.runes.length <= 254 && _email.hasMatch(email));
