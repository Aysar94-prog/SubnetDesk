using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace SubnetDesk.Deployment {
    internal static class EmbeddedRegistration {
        internal static void CopyRuntime(string source, string destination) {
            var registration = Read(source);
            using (var input = File.OpenRead(source)) using (var output = File.Create(destination)) {
                long remaining = input.Length;
                if (registration != null) {
                    int magicLength = Encoding.UTF8.GetByteCount("SUBNETDESK_ENROLLMENT_V1"); input.Position = input.Length - magicLength - 4;
                    byte[] bytes = new byte[4]; if (input.Read(bytes, 0, 4) != 4) throw new InvalidDataException("Invalid enrollment footer.");
                    remaining -= magicLength + 4 + BitConverter.ToInt32(bytes, 0); input.Position = 0;
                }
                var buffer = new byte[65536];
                while (remaining > 0) { int count = input.Read(buffer, 0, (int)Math.Min(buffer.Length, remaining)); if (count == 0) throw new EndOfStreamException(); output.Write(buffer, 0, count); remaining -= count; }
            }
        }
        internal static Dictionary<string, object> Read(string path) {
            byte[] magic = Encoding.UTF8.GetBytes("SUBNETDESK_ENROLLMENT_V1");
            using (var stream = File.OpenRead(path)) using (var reader = new BinaryReader(stream)) {
                if (stream.Length < magic.Length + 4) return null;
                stream.Position = stream.Length - magic.Length;
                if (!Data.Equal(Encoding.UTF8.GetString(reader.ReadBytes(magic.Length)), Encoding.UTF8.GetString(magic))) return null;
                stream.Position = stream.Length - magic.Length - 4;
                int length = reader.ReadInt32();
                if (length < 1 || length > 8192 || length > stream.Length - magic.Length - 4) throw new InvalidDataException("Invalid embedded registration length.");
                stream.Position = stream.Length - magic.Length - 4 - length;
                var config = Data.Parse(Encoding.UTF8.GetString(reader.ReadBytes(length)));
                Data.Endpoint(Data.Text(config, "server"));
                if (!System.Text.RegularExpressions.Regex.IsMatch(Data.Text(config, "certificateSha256"), "^[A-Fa-f0-9]{64}$")) throw new InvalidDataException("Invalid embedded server identity.");
                if (Data.Text(config, "approvalRequired") != "true" && Convert.FromBase64String(Data.Text(config, "enrollmentToken")).Length != 32) throw new InvalidDataException("Invalid embedded registration.");
                return config;
            }
        }
    }
}
