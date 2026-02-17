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

  function sharp(input: string | Buffer): SharpInstance;
  export default sharp;
}

declare module 'ws' {
  import { EventEmitter } from 'events';
  import { Server as HttpServer } from 'http';

  export class WebSocket extends EventEmitter {
    static readonly OPEN: number;
    static readonly CLOSED: number;
    static readonly CONNECTING: number;
    static readonly CLOSING: number;

    readyState: number;

    constructor(address: string, options?: any);
    send(data: string | Buffer, callback?: (err?: Error) => void): void;
    close(code?: number, reason?: string): void;
    on(event: 'message', listener: (data: Buffer | string) => void): this;
    on(event: 'close', listener: () => void): this;
    on(event: 'error', listener: (err: Error) => void): this;
    on(event: string, listener: (...args: any[]) => void): this;
  }

  export class WebSocketServer extends EventEmitter {
    constructor(options: { server?: HttpServer; port?: number; [key: string]: any });
    on(event: 'connection', listener: (ws: WebSocket, request: any) => void): this;
    on(event: string, listener: (...args: any[]) => void): this;
    close(callback?: () => void): void;
  }
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
