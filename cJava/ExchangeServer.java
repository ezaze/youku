import org.vertx.java.core.Handler;
import org.vertx.java.core.http.HttpServerRequest;
import org.vertx.java.core.json.JsonArray;
import org.vertx.java.core.json.JsonObject;
import org.vertx.java.core.json.impl.Json;
import org.vertx.java.platform.Verticle;




public class ExchangeServer extends Verticle {
	public void start() {
		vertx.createHttpServer().requestHandler(req -> req.response("abc").end()).listen(5000);
}
}
