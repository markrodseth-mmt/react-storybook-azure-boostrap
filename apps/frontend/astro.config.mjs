import { defineConfig } from "astro/config";
import node from "@astrojs/node";
import react from "@astrojs/react";
import storyblok from "@storyblok/astro";

export default defineConfig({
  output: "server",
  adapter: node({ mode: "standalone" }),
  integrations: [
    react(),
    storyblok({
      accessToken: import.meta.env.STORYBLOK_TOKEN ?? process.env.STORYBLOK_TOKEN,
      bridge: import.meta.env.DEV,
      apiOptions: {
        region: "eu",
      },
      components: {
        page: "storyblok/Page",
        hero: "storyblok/Hero",
        richtext: "storyblok/RichText",
        image: "storyblok/Image",
      },
    }),
  ],
  server: { port: Number(process.env.PORT) || 4321, host: "0.0.0.0" },
});
