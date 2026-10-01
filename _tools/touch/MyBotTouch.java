// Multi-touch gestures for an Android that the ADB shell cannot touch through /dev/input (Waydroid: no touch
// device, no root). Run by the shell user, which may inject input events, the way scrcpy does:
//
//   adb shell CLASSPATH=/data/local/tmp/mybot-touch.dex app_process / MyBotTouch pinch <cx> <cy> <from> <to> <ms> [count]
//
// pinch: two fingers centred on (cx, cy), from <from> to <to> pixels apart, in <ms> milliseconds, <count> times.
// Fingers coming together (from > to) zoom out. Built by _tools/touch/build.sh into lib/adb.scripts.
//
// Android classes are reached by reflection only, so this compiles with a plain JDK (no Android SDK).
import java.lang.reflect.Array;
import java.lang.reflect.Method;

public class MyBotTouch {
	private static final int ACTION_DOWN = 0, ACTION_UP = 1, ACTION_MOVE = 2, ACTION_POINTER_DOWN = 5, ACTION_POINTER_UP = 6;
	private static final int SOURCE_TOUCHSCREEN = 0x1002, TOOL_TYPE_FINGER = 1, INJECT_ASYNC = 0;

	private static Object inputManager;
	private static Method inject, obtain, recycle, uptime;
	private static Class<?> propsClass, coordsClass;

	public static void main(String[] args) throws Exception {
		if (args.length < 6 || !args[0].equals("pinch")) {
			System.err.println("usage: MyBotTouch pinch <cx> <cy> <from> <to> <ms> [count]");
			System.exit(2);
		}
		init();
		float cx = Float.parseFloat(args[1]), cy = Float.parseFloat(args[2]);
		float from = Float.parseFloat(args[3]), to = Float.parseFloat(args[4]);
		int ms = Integer.parseInt(args[5]);
		int count = args.length > 6 ? Integer.parseInt(args[6]) : 1;
		for (int i = 0; i < count; i++) {
			pinch(cx, cy, from, to, ms);
			Thread.sleep(150);
		}
		System.out.println("ok");
	}

	private static void init() throws Exception {
		Class<?> im;
		try {
			im = Class.forName("android.hardware.input.InputManagerGlobal"); // Android 14+
		} catch (ClassNotFoundException e) {
			im = Class.forName("android.hardware.input.InputManager");
		}
		inputManager = im.getMethod("getInstance").invoke(null);
		inject = im.getMethod("injectInputEvent", Class.forName("android.view.InputEvent"), int.class);
		Class<?> me = Class.forName("android.view.MotionEvent");
		propsClass = Class.forName("android.view.MotionEvent$PointerProperties");
		coordsClass = Class.forName("android.view.MotionEvent$PointerCoords");
		Object propsArray = Array.newInstance(propsClass, 0), coordsArray = Array.newInstance(coordsClass, 0);
		obtain = me.getMethod("obtain", long.class, long.class, int.class, int.class, propsArray.getClass(), coordsArray.getClass(),
				int.class, int.class, float.class, float.class, int.class, int.class, int.class, int.class);
		recycle = me.getMethod("recycle");
		uptime = Class.forName("android.os.SystemClock").getMethod("uptimeMillis");
	}

	// both fingers on the diagonal through the centre, d pixels apart
	private static void pinch(float cx, float cy, float from, float to, int ms) throws Exception {
		int steps = Math.max(2, ms / 10);
		long down = (Long) uptime.invoke(null);
		float[][] p = positions(cx, cy, from);
		send(down, ACTION_DOWN, 1, p);
		send(down, ACTION_POINTER_DOWN | (1 << 8), 2, p);
		for (int s = 1; s <= steps; s++) {
			Thread.sleep(ms / steps);
			p = positions(cx, cy, from + (to - from) * s / steps);
			send(down, ACTION_MOVE, 2, p);
		}
		send(down, ACTION_POINTER_UP | (1 << 8), 2, p);
		send(down, ACTION_UP, 1, p);
	}

	private static float[][] positions(float cx, float cy, float d) {
		float h = d / 2 / (float) Math.sqrt(2);
		return new float[][] { { cx - h, cy - h }, { cx + h, cy + h } };
	}

	private static void send(long down, int action, int pointers, float[][] p) throws Exception {
		Object props = Array.newInstance(propsClass, pointers), coords = Array.newInstance(coordsClass, pointers);
		for (int i = 0; i < pointers; i++) {
			Object pp = propsClass.newInstance();
			propsClass.getField("id").setInt(pp, i);
			propsClass.getField("toolType").setInt(pp, TOOL_TYPE_FINGER);
			Array.set(props, i, pp);
			Object pc = coordsClass.newInstance();
			coordsClass.getField("x").setFloat(pc, p[i][0]);
			coordsClass.getField("y").setFloat(pc, p[i][1]);
			coordsClass.getField("pressure").setFloat(pc, 1f);
			coordsClass.getField("size").setFloat(pc, 1f);
			Array.set(coords, i, pc);
		}
		long now = (Long) uptime.invoke(null);
		Object ev = obtain.invoke(null, down, now, action, pointers, props, coords, 0, 0, 1f, 1f, 0, 0, SOURCE_TOUCHSCREEN, 0);
		inject.invoke(inputManager, ev, INJECT_ASYNC);
		recycle.invoke(ev);
	}
}
