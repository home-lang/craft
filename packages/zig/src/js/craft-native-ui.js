(function(){'use strict';if(!window.craft)window.craft={};
function s(a,d){if(!window.webkit?.messageHandlers?.craft)throw new Error('Craft bridge not available');
window.webkit.messageHandlers.craft.postMessage({t:'nativeUI',a:a,d:d})}
class Sidebar{constructor(id){this.id=id;this._selectCallbacks=[];this._contextMenuCallbacks=[]}
addSection(section){s('addSidebarSection',{sidebarId:this.id,section:section});return this}
setSelectedItem(itemId){s('setSelectedItem',{sidebarId:this.id,itemId:itemId});return this}
onSelect(cb){this._selectCallbacks.push(cb);return this}
onContextMenu(cb){this._contextMenuCallbacks.push(cb);return this}
showContextMenu(o){s('showContextMenu',{targetId:o.itemId,targetType:'sidebar',x:o.x,y:o.y,items:o.items||[{id:'rename',title:'Rename...',icon:'pencil'},{id:'s1',title:'',type:'separator'},{id:'new_folder',title:'New Folder',icon:'folder.badge.plus',shortcut:'cmd+shift+n'},{id:'s2',title:'',type:'separator'},{id:'remove',title:'Remove from Sidebar',icon:'minus.circle'}]});return this}
destroy(){s('destroyComponent',{id:this.id,type:'sidebar'})}}
class FileBrowser{constructor(id){this.id=id;this._selectCallbacks=[];this._doubleClickCallbacks=[];this._contextMenuCallbacks=[]}
addFile(f){s('addFile',{browserId:this.id,file:f});return this}
addFiles(f){s('addFiles',{browserId:this.id,files:f});return this}
clearFiles(){s('clearFiles',{browserId:this.id});return this}
onSelect(cb){this._selectCallbacks.push(cb);return this}
onDoubleClick(cb){this._doubleClickCallbacks.push(cb);return this}
onContextMenu(cb){this._contextMenuCallbacks.push(cb);return this}
showContextMenu(o){s('showContextMenu',{targetId:o.fileId,targetType:'file',x:o.x,y:o.y,items:o.items||[{id:'open',title:'Open',icon:'arrow.up.forward.square',shortcut:'cmd+o'},{id:'open_with',title:'Open With...',icon:'arrow.up.forward.app'},{id:'s1',title:'',type:'separator'},{id:'get_info',title:'Get Info',icon:'info.circle',shortcut:'cmd+i'},{id:'rename',title:'Rename',icon:'pencil'},{id:'s2',title:'',type:'separator'},{id:'copy',title:'Copy',icon:'doc.on.doc',shortcut:'cmd+c'},{id:'duplicate',title:'Duplicate',icon:'plus.square.on.square',shortcut:'cmd+d'},{id:'s3',title:'',type:'separator'},{id:'move_to_trash',title:'Move to Trash',icon:'trash',shortcut:'cmd+delete'}]});return this}
previewFile(fid,fp,t){s('showQuickLook',{files:[{id:fid,path:fp,title:t}]});return this}
previewFiles(f,i=0){s('showQuickLook',{files:f,currentIndex:i});return this}
toggleQuickLook(f,i=0){s('toggleQuickLook',{files:f,currentIndex:i});return this}
destroy(){s('destroyComponent',{id:this.id,type:'fileBrowser'})}}
class SplitView{constructor(id,sb,br){this.id=id;this.sidebar=sb;this.browser=br}
setDividerPosition(p){s('setDividerPosition',{splitViewId:this.id,position:p});return this}
destroy(){s('destroyComponent',{id:this.id,type:'splitView'})}}
window.craft.nativeUI={
createSidebar(o={}){const id=o.id||`sidebar-${Date.now()}-${Math.random().toString(36).substr(2,9)}`;s('createSidebar',{id});return new Sidebar(id)},
createFileBrowser(o={}){const id=o.id||`browser-${Date.now()}-${Math.random().toString(36).substr(2,9)}`;s('createFileBrowser',{id});return new FileBrowser(id)},
createSplitView(o){if(!o.sidebar||!o.browser)throw new Error('createSplitView requires both sidebar and browser options');const id=o.id||`splitview-${Date.now()}-${Math.random().toString(36).substr(2,9)}`;s('createSplitView',{id:id,sidebarId:o.sidebar.id,browserId:o.browser.id});return new SplitView(id,o.sidebar,o.browser)},
showContextMenu(o){if(!o.items||!o.items.length)throw new Error('showContextMenu requires items array');s('showContextMenu',{targetId:o.targetId||'',targetType:o.targetType||'general',x:o.x||0,y:o.y||0,items:o.items})},
showQuickLook(o){if(!o.files||!o.files.length)throw new Error('showQuickLook requires files array');s('showQuickLook',{files:o.files,currentIndex:o.currentIndex||0})},
closeQuickLook(){s('closeQuickLook',{})},
toggleQuickLook(o){if(!o.files||!o.files.length)throw new Error('toggleQuickLook requires files array');s('toggleQuickLook',{files:o.files,currentIndex:o.currentIndex||0})},
previewFile(fp,t){this.showQuickLook({files:[{id:fp,path:fp,title:t}]})}};
document.dispatchEvent(new CustomEvent('craft:nativeui:ready'))})();
