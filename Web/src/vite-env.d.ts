/// <reference types="vite/client" />

declare module 'us-zips' {
  // us-zips default export: { [zip: string]: { latitude: number; longitude: number } }
  const zips: Record<string, { latitude: number; longitude: number }>
  export default zips
}
