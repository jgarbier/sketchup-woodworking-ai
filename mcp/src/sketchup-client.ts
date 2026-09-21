import net from 'node:net';
import {randomUUID} from 'node:crypto';
import {mkdir,appendFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {commandSchemas,responseSchema,type Command} from './schemas.js';
export class SketchupClient {
  constructor(private port=48763, private timeoutMs=120000) {}
  async call(command:Command, input:unknown) {
    const params=commandSchemas[command].parse(input);
    const request_id=randomUUID();
    const start=Date.now();
    let response:unknown;
    try {
      response=await new Promise((resolve,reject)=>{
        const socket=net.createConnection({host:'127.0.0.1',port:this.port});
        let data=Buffer.alloc(0);
        const timer=setTimeout(()=>socket.destroy(new Error('SketchUp bridge timed out. Dismiss modal dialogs and query the part before retrying a mutation.')),this.timeoutMs);
        socket.once('close',()=>clearTimeout(timer));
        socket.once('error',reject);
        socket.once('connect',()=>socket.write(JSON.stringify({request_id,command,params})+'\n'));
        socket.on('data',(chunk:Buffer)=>{
          data=Buffer.concat([data,chunk]);
          if(data.length>65536) return socket.destroy(new Error('Bridge response exceeds 64 KiB'));
          if(!data.includes(10)) return;
          try {
            const parsed=responseSchema.parse(JSON.parse(data.subarray(0,data.indexOf(10)).toString('utf8')));
            if(parsed.request_id!==request_id) throw new Error('Bridge response request ID mismatch');
            socket.destroy(); resolve(parsed);
          } catch(e) {socket.destroy();reject(e);}
        });
        socket.once('end',()=>{if(!data.includes(10)) reject(new Error('Bridge closed without a complete response'));});
      });
      return responseSchema.parse(response);
    } catch(e) {
      response={request_id,success:false as const,error:{code:'BRIDGE_CONNECTION_ERROR',message:e instanceof Error?e.message:String(e)}};
      return responseSchema.parse(response);
    } finally {
      try {
        const dir=fileURLToPath(new URL('../logs/',import.meta.url));
        await mkdir(dir,{recursive:true});
        await appendFile(dir+'mcp.jsonl',JSON.stringify({timestamp:new Date().toISOString(),tool:command,command,request_id,parameters:params,duration_ms:Date.now()-start,response})+'\n',{mode:0o600});
      } catch {console.error('Woodworking MCP could not write its log');}
    }
  }
}
