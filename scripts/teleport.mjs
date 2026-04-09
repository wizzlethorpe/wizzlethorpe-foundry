const FLAG = "wizzlethorpe-labs";

Hooks.on("ready", () => {
  Wizzlethorpe.socket.register("teleportToRegion", async (data) => {
    const token = await fromUuid(data.tokenUuid);
    if (!token) return console.error("Token not found:", data.tokenUuid);

    const region = await fromUuid(data.regionUuid);
    if (!region) return console.error("Region not found:", data.regionUuid);

    await region.teleportToken(token);

    if (data.userId) {
      await region.parent.pullUsers([data.userId]);
    }
  });

  Wizzlethorpe.socket.register("teleportToPosition", async (data) => {
    const token = await fromUuid(data.tokenUuid);
    if (!token) return console.error("Token not found:", data.tokenUuid);

    const scene = game.scenes.get(data.sceneId);
    if (!scene) return console.error("Scene not found:", data.sceneId);

    if (data.clearFlag) {
      await token.unsetFlag(FLAG, data.clearFlag);
    }

    const regionDoc = new RegionDocument({
      name: "Teleport Landing",
      shapes: [{
        type: "rectangle",
        x: data.x,
        y: data.y,
        width: data.width ?? 100,
        height: data.height ?? 100,
        rotation: 0
      }]
    }, { parent: scene });

    await regionDoc.teleportToken(token);

    if (data.userId) {
      await scene.pullUsers([data.userId]);
    }
  });
});