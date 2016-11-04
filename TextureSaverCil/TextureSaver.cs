using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

namespace TextureSaverCil
{
    public class TextureSaver
    {
		public static string SaveBitmapInTemp(int width, int height, byte[] imageData)
		{
			var tempFile = Path.ChangeExtension(Path.GetTempFileName(), ".jpg");

			var data = new byte[width * height * 4];
			var o = 0;

			for (var i = 0; i < width * height; i++)
			{
				data[o++] = imageData[(i * 3) + 2];				
				data[o++] = imageData[(i*3)+1];
				data[o++] = imageData[i * 3];
				data[o++] = 0;
			}

			unsafe
			{
				fixed (byte* ptr = data)
				{
					using (var image = new Bitmap(width, height, width * 4,
								PixelFormat.Format32bppRgb, new IntPtr(ptr)))
					{
						image.Save(tempFile);
					}
				}
			}

			return tempFile;
		}
    }
}
