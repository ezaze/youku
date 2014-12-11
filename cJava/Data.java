class Data {
public static void main(String[] args){
    String cookie = "1|1411437991|15|aWQ6NDI5NzkxNTU0LG5uOmxlYXB5ZWFyNzkyOTQ5NDEsdmlwOmZhbHNlLHl0aWQ6NDI5NzkxNTU0LHRpZDow|d17bd01d123d09c79e54d6fafa290522|2de429fc5316d4a1d4f64746011a5330f40a7864|1";
    String info = URLDecoder.decode(cookie, "utf-8");
    System.out.println(info);
    }

}
