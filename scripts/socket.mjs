if (!globalThis.Wizzlethorpe) {
  globalThis.Wizzlethorpe = {
    MODULE_ID: "wizzlethorpe-labs",
    handlers: {},
    socket: {
      register(action, handler) {
        Wizzlethorpe.handlers[action] = handler;
        console.log(`Wizzlethorpe | Handler registered: ${action}`);
      },
      emit(action, data) {
        game.socket.emit(`module.${Wizzlethorpe.MODULE_ID}`, { action, ...data });
      }
    }
  };

  Hooks.on("ready", () => {
    game.socket.on(`module.${Wizzlethorpe.MODULE_ID}`, async (data) => {
      const handler = Wizzlethorpe.handlers[data.action];
      if (!handler) return;

      if (game.user.isGM) {
        const activeGM = game.users.find(u => u.isGM && u.active);
        if (game.user !== activeGM) return;
      }

      console.log(`Wizzlethorpe | Socket received:`, data);
      await handler(data);
    });

    console.log(`Wizzlethorpe | Socket listener active.`);
  });
}