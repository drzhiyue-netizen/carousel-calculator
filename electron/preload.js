const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('carousel', {
  close: () => ipcRenderer.send('win:close'),
  minimize: () => ipcRenderer.send('win:minimize'),
  getState: () => ipcRenderer.invoke('win:getState'),
  setSize: (width, height) => ipcRenderer.send('win:setSize', { width, height }),
});
