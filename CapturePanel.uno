using Uno;
using Fuse;
using Fuse.Controls;
using Fuse.Scripting;
using Fuse.Reactive;
using OpenGL;
using Uno.Compiler.ExportTargetInterop;
using Uno.Threading;
using Uno.IO;

class CallJSClosure
{
	readonly Context _context;
	readonly Function _func;
	
	public CallJSClosure(Context context, Function func)
	{
		_context = context;
		_func = func;
	}

	object _arg;
	public void Run(object arg)
	{	
		_arg = arg;
		_context.Invoke(RunInternal);
	}
	
	void RunInternal(Fuse.Scripting.Context ctx)
	{
		_func.Call(ctx, _arg);
	}
}

public class CapturePanel : Panel
{
	static CapturePanel()
	{
		ScriptClass.Register(typeof(CapturePanel), new ScriptMethod<CapturePanel>("capture", CaptureAsync, ExecutionThread.MainThread));
	}
	
	static void CaptureAsync(Context ctx, CapturePanel capturePanel, object[] args)
	{
		var callback = args[0] as Function;
		capturePanel.TriggerCapture(ctx, callback);
	}
	
	CallJSClosure _captureCallback;
	
	public void TriggerCapture(Context ctx, Function captureCallback)
	{
		_captureCallback = new CallJSClosure(ctx, captureCallback);
		InvalidateVisual();
	}

	protected override void DrawVisual(DrawContext dc)
	{
		if(_captureCallback != null)
		{
			var callback = _captureCallback;
			_captureCallback = null;
			callback.Run(Capture(dc));
		}
	}

	string Capture(DrawContext dc)
	{
		var fb = CaptureRegion(dc, new Rect(0, 0, ActualSize.X, ActualSize.Y), float2(0));

		dc.PushRenderTarget(fb);
		var width = fb.Size.X;
		var height = fb.Size.Y;

		var imageBytes = new byte[width * height * 4];
		GL.ReadPixels(0, 0, width, height, GLPixelFormat.Rgba, GLPixelType.UnsignedByte, imageBytes);
		dc.PopRenderTarget();
		FramebufferPool.Release(fb);

		var rgbBytes = new byte[width * height * 3];
		var curIdx = 0;
		for(var y = height-1;y >= 0;--y)
			for(var x = 0;x < width;++x)
			{
				var idx = (y * width + x) * 4;
				rgbBytes[curIdx++] = imageBytes[idx];
				rgbBytes[curIdx++] = imageBytes[idx + 1];
				rgbBytes[curIdx++] = imageBytes[idx + 2];
			}
		return JpegSaver.CreateAndSaveJpegTmp(width, height, rgbBytes);
	}
}

extern(DotNet) static class JpegSaver
{
	public static string CreateAndSaveJpegTmp(int width, int height, byte []bytes)
	{
		return TextureSaver.SaveBitmapInTemp(width, height, bytes);
	}
}

[DotNetType("TextureSaverCil.TextureSaver")]
extern(DOTNET) public class TextureSaver
{
	extern public static string SaveBitmapInTemp(int width, int height, byte[] imageData);
}

[TargetSpecificImplementation]
[ForeignInclude(Language.Java, "com.fuse.Activity")]
[ForeignInclude(Language.ObjC, "Foundation/Foundation.h")]
extern(Mobile) static class JpegSaver
{
	public static string CreateAndSaveJpegTmp(int width, int height, byte []bytes)
	{
		var path = GetTempPath();
		JpegSaver.ByteArrayRgbaToJpeg(new Buffer(bytes), width, height, path);
		return path;
	}

	[TargetSpecificImplementation]
	public static void ByteArrayRgbaToJpeg(Uno.Buffer b, int width, int height, string path)
	{
	}

	[Foreign(Language.Java)]
	extern(Android) static string GetTempPath()
	@{
		java.io.File dir = Activity.getRootActivity().getCacheDir();
		if(dir == null)
			return "";

		String containingPath = dir.getAbsolutePath();
		String uuid = java.util.UUID.randomUUID().toString();
		return containingPath + "/" + uuid + ".jpg";
	@}

	[Foreign(Language.ObjC)]
	extern(iOS) static string GetTempPath()
	@{
		NSString *uniqueIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
		return [[NSTemporaryDirectory() stringByAppendingPathComponent:uniqueIdentifier] stringByAppendingPathExtension:@"jpg"];
	@}
}