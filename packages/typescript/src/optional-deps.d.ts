/**
 * Type declarations for optional native dependencies.
 * These modules are NOT bundled with this package - they are optional
 * runtime dependencies that may or may not be installed.
 * These minimal declarations allow TypeScript to compile without errors
 * when the packages are not installed.
 */

declare module 'sharp' {
  interface SharpInstance {
    resize(width?: number, height?: number, options?: { fit?: string; withoutEnlargement?: boolean }): SharpInstance;
    rotate(): SharpInstance;
    webp(options?: { quality?: number }): SharpInstance;
    avif(options?: { quality?: number }): SharpInstance;
    png(options?: { compressionLevel?: number; progressive?: boolean }): SharpInstance;
    jpeg(options?: { quality?: number; progressive?: boolean }): SharpInstance;
    toFile(path: string): Promise<any>;
  }

  function sharp(_input: string | Buffer): SharpInstance;
  export default sharp;
}

declare module '@stacksjs/clapp' {
  export class CLI {
    constructor(name: string);
    command(name: string, description?: string): CommandBuilder;
    version(version: string): this;
    help(): this;
    parse(): void;
  }

  interface CommandBuilder {
    option(flags: string, description?: string, options?: { default?: any }): CommandBuilder;
    example(text: string): CommandBuilder;
    action(fn: (...args: any[]) => any): CommandBuilder;
  }
}
