// Diagnostic-only C# 5 interop for Windows PowerShell 5 Add-Type.
// ABI: microsoft/win32metadata UIAutomationClient.idl blob
// 655287aeae4608114bd8ea77713e5cb1792a5c69; UIAutomationCoreApi.h blob
// 675367b41c8961fb92ec47c4a84246ef1356b6e8. Only interface prefixes are
// declared, in original vtable order; unused methods are never called.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Threading;

namespace DwmNativeProvider
{
    [ComImport, Guid("30cbe57d-d9d0-452a-ab13-7ac5ac4825ee")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAutomation
    {
        [PreserveSig] int CompareElements(IntPtr first, IntPtr second,
            [MarshalAs(UnmanagedType.Bool)] out bool same);
        [PreserveSig] int CompareRuntimeIds(
            [MarshalAs(UnmanagedType.SafeArray, SafeArraySubType = VarEnum.VT_I4)] int[] first,
            [MarshalAs(UnmanagedType.SafeArray, SafeArraySubType = VarEnum.VT_I4)] int[] second,
            [MarshalAs(UnmanagedType.Bool)] out bool same);
        [PreserveSig] int GetRootElement([MarshalAs(UnmanagedType.Interface)] out IElement root);
        [PreserveSig] int ElementFromHandle(IntPtr hwnd,
            [MarshalAs(UnmanagedType.Interface)] out IElement element);
    }

    [ComImport, Guid("d22108aa-8ac5-49a5-837b-37bbb3d7591e")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IElement
    {
        [PreserveSig] int SetFocus(); // ABI slot only; never invoked.
        [PreserveSig] int GetRuntimeId(
            [MarshalAs(UnmanagedType.SafeArray, SafeArraySubType = VarEnum.VT_I4)] out int[] ids);
        [PreserveSig] int FindFirst(int scope, IntPtr condition,
            [MarshalAs(UnmanagedType.Interface)] out IElement found);
        [PreserveSig] int FindAll(int scope, IntPtr condition, out IntPtr found);
        [PreserveSig] int FindFirstBuildCache(int scope, IntPtr condition, IntPtr cache,
            [MarshalAs(UnmanagedType.Interface)] out IElement found);
        [PreserveSig] int FindAllBuildCache(int scope, IntPtr condition, IntPtr cache, out IntPtr found);
        [PreserveSig] int BuildUpdatedCache(IntPtr cache,
            [MarshalAs(UnmanagedType.Interface)] out IElement updated);
        [PreserveSig] int GetCurrentPropertyValue(int propertyId,
            [MarshalAs(UnmanagedType.Struct)] out object value);
        [PreserveSig] int GetCurrentPropertyValueEx(int propertyId,
            [MarshalAs(UnmanagedType.Bool)] bool ignoreDefault,
            [MarshalAs(UnmanagedType.Struct)] out object value);
    }

    public sealed class Result
    {
        public string Operation { get; set; }
        public int? PropertyId { get; set; }
        public string HResult { get; set; }
        public string NativeCall { get; set; }
        public string State { get; set; }
        public object Value { get; set; }
        public string ValueType { get; set; }
        public string Error { get; set; }
        public string ErrorHResult { get; set; }
    }

    public sealed class Session : IDisposable
    {
        public const string ClientClsid = "ff48dba4-60ef-4201-aa87-54103eef594e";
        private IAutomation client;
        private IElement element;
        private IntPtr notSupported;
        private bool activated;
        private bool attachAttempted;
        private bool disposed;
        private readonly int threadId = Thread.CurrentThread.ManagedThreadId;
        private readonly List<Result> operations = new List<Result>();
        private readonly List<string> cleanupErrors = new List<string>();

        [DllImport("UIAutomationCore.dll", ExactSpelling = true)]
        private static extern int UiaGetReservedNotSupportedValue(out IntPtr value);

        public string Apartment { get { return Thread.CurrentThread.GetApartmentState().ToString(); } }
        public string InteropAssembly { get { return typeof(Session).Assembly.FullName; } }
        public Result[] Operations { get { return operations.ToArray(); } }
        public string[] CleanupErrors { get { return cleanupErrors.ToArray(); } }

        private static string Hex(int value)
        {
            return "0x" + unchecked((uint)value).ToString("X8", CultureInfo.InvariantCulture);
        }
        private Result Begin(string operation, int? property)
        {
            Result result = new Result { Operation = operation, PropertyId = property, State = "error" };
            operations.Add(result);
            return result;
        }
        private static void Fail(Result result, Exception error)
        {
            result.State = "error";
            result.Error = error.GetType().FullName + ": " + error.Message;
            result.ErrorHResult = Hex(error.HResult);
        }
        private void CheckThread()
        {
            if (Thread.CurrentThread.ManagedThreadId != threadId)
                throw new InvalidOperationException("NATIVE_PROVIDER_THREAD_CHANGED");
            if (disposed) throw new ObjectDisposedException("Session");
        }
        private static bool NativeSucceeded(Result result, int hr)
        {
            result.HResult = Hex(hr);
            if (hr >= 0) return true;
            result.Error = "Native HRESULT failure";
            return false;
        }

        // Capability-only preflight may call Activate/Dispose: neither method
        // obtains a window, root element, UI tree, property, pattern or input.
        public Result Activate()
        {
            Result result = Begin("activate", null);
            object created = null;
            try
            {
                CheckThread();
                if (activated || client != null || notSupported != IntPtr.Zero)
                    throw new InvalidOperationException("NATIVE_PROVIDER_ALREADY_ACTIVATED");
                result.NativeCall = "UiaGetReservedNotSupportedValue";
                if (!NativeSucceeded(result, UiaGetReservedNotSupportedValue(out notSupported))) return result;
                if (notSupported == IntPtr.Zero)
                    throw new InvalidOperationException("NATIVE_PROVIDER_NULL_RESERVED_VALUE");
                // Activator reports failures by exception; HResult above belongs
                // to UiaGetReservedNotSupportedValue, not CoCreateInstance.
                created = Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid(ClientClsid), true));
                client = (IAutomation)created;
                created = null; // Ownership transferred to client; one RCW release.
                activated = true;
                result.State = "ok";
                result.Value = ClientClsid;
                result.ValueType = "CLSID";
            }
            catch (Exception error) { Fail(result, error); }
            finally { ReleaseRcw(created, "unassigned_client"); }
            return result;
        }

        public Result Attach(IntPtr hwnd)
        {
            Result result = Begin("element_from_handle", null);
            try
            {
                CheckThread();
                if (!activated || attachAttempted || hwnd == IntPtr.Zero)
                    throw new InvalidOperationException("NATIVE_PROVIDER_ATTACH_STATE_INVALID");
                attachAttempted = true;
                result.NativeCall = "IUIAutomation.ElementFromHandle";
                if (!NativeSucceeded(result, client.ElementFromHandle(hwnd, out element))) return result;
                if (element == null) throw new InvalidOperationException("NATIVE_PROVIDER_NULL_ELEMENT");
                result.State = "ok";
            }
            catch (Exception error) { Fail(result, error); }
            return result;
        }

        public Result Read(int propertyId)
        {
            Result result = Begin("get_current_property_value_ex", propertyId);
            object value = null;
            IntPtr identity = IntPtr.Zero;
            try
            {
                CheckThread();
                if (element == null || (propertyId != 30002 && propertyId != 30020 && propertyId != 30107))
                    throw new InvalidOperationException("NATIVE_PROVIDER_PROPERTY_SCOPE_INVALID");
                result.NativeCall = "IUIAutomationElement.GetCurrentPropertyValueEx";
                if (!NativeSucceeded(result, element.GetCurrentPropertyValueEx(propertyId, true, out value)))
                    return result;
                result.ValueType = value == null ? null : value.GetType().FullName;
                if (value == null) result.State = "null"; // Marshaled VT_EMPTY.
                else if (value == DBNull.Value) result.State = "null_variant"; // VT_NULL.
                else if (Marshal.IsComObject(value))
                {
                    identity = Marshal.GetIUnknownForObject(value);
                    result.State = identity == notSupported ? "unsupported" : "unexpected_type";
                    // Never serialize a COM object or call its ToString.
                }
                else if (propertyId == 30107 && value is string)
                {
                    result.Value = (string)value;
                    result.State = ((string)value).Length == 0 ? "empty" : "value";
                }
                else if (propertyId != 30107 && value is int)
                {
                    result.Value = (int)value;
                    result.State = "value";
                }
                else result.State = "unexpected_type";
            }
            catch (Exception error) { Fail(result, error); }
            finally
            {
                ReleasePointer(identity, "property_identity");
                ReleaseRcw(value, "property_value");
            }
            return result;
        }

        private void ReleaseRcw(object value, string label)
        {
            try { if (value != null && Marshal.IsComObject(value)) Marshal.ReleaseComObject(value); }
            catch (Exception error) { cleanupErrors.Add(label + ": " + Hex(error.HResult) + " " + error.Message); }
        }
        private void ReleasePointer(IntPtr value, string label)
        {
            try { if (value != IntPtr.Zero) Marshal.Release(value); }
            catch (Exception error) { cleanupErrors.Add(label + ": " + Hex(error.HResult) + " " + error.Message); }
        }
        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            if (Thread.CurrentThread.ManagedThreadId != threadId)
                cleanupErrors.Add("dispose: NATIVE_PROVIDER_THREAD_CHANGED");
            // Do not use FinalReleaseComObject: these are one owned acquisition
            // each, and another RCW reference must never be invalidated forcibly.
            ReleaseRcw(element, "element"); element = null;
            ReleaseRcw(client, "client"); client = null;
            ReleasePointer(notSupported, "reserved_not_supported"); notSupported = IntPtr.Zero;
        }
    }
}
