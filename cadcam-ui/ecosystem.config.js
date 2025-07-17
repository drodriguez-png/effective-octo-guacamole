module.exports = {
  apps: [
    {
      name: "cadcam-cds",
      script: "bun",
      args: "run dev --host",
      autorestart: true,
      watch: true,
    },
  ],
};
