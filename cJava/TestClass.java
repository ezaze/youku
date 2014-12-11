public class TestClass {
    public static void main(String[] args) {
try{
    Class testTypeForName=Class.forName("TestClassType");
    System.out.println("testForname----"+testTypeForName);

    Class testTypeClass=TestClassType.class;
    System.out.println("testTypeClass---"+testTypeClass);

    TestClassType testGetClass = new TestClassType();
    System.out.println("testGetClass---"+testGetClass.getClass());

    

    }catch (ClassNotFoundException e) {
        e.printStackTrace();
    }
    }
}

class TestClassType {
    public TestClassType(){
        System.out.println("====构造函数");
    }
    static{
        System.out.println("---静态的参数初始化");
    }
    {
        System.out.println("--非静态参数的初始化");
    }

   
}
