bool listsEqual/*<T>*/(List<dynamic/*=T*/> a, List<dynamic/*=T*/> b) {
  if (a == null && b == null)
    return true;
  if (a == null || b == null)
    return false;
  if (a.length != b.length)
    return false;
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index])
      return false;
  }
  return true;
}

bool setsEqual/*<T>*/(Set<dynamic/*=T*/> a, Set<dynamic/*=T*/> b) {
  if (a == null && b == null)
    return true;
  if (a == null || b == null)
    return false;
  if (a.length != b.length)
    return false;
  for (dynamic/*=T*/ value in a) {
    if (!b.contains(value))
      return false;
  }
  return true;
}
