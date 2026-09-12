import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const stack = readFileSync("docker-stack.portainer.yml", "utf8");

describe("stack Portainer", () => {
  it("usa a rede e o provider Swarm já existentes", () => {
    expect(stack).toContain("network_public:\n    external: true");
    expect(stack).toContain("traefik.swarm.network=network_public");
    expect(stack).toContain("entrypoints=websecure");
    expect(stack).toContain("tls.certresolver=letsencryptresolver");
  });

  it("puxa as três imagens próprias pela mesma versão imutável", () => {
    expect(stack).toContain('docker.io/${DOCKERHUB_NAMESPACE}/deskcommcrm:${CRM_VERSION}');
    expect(stack).toContain('docker.io/${DOCKERHUB_NAMESPACE}/deskcomm-worker:${CRM_VERSION}');
    expect(stack).toContain('docker.io/${DOCKERHUB_NAMESPACE}/deskcomm-scheduler:${CRM_VERSION}');
    expect(stack).not.toContain("build:");
  });

  it("deixa somente o app na rede pública e mantém o webhook interno", () => {
    expect(stack).toContain("      - network_public");
    expect(stack).toContain('WAHA_WEBHOOK_BASE_URL: "http://app:3000"');
    expect(stack).toContain('WHATSAPP_HOOK_URL: "http://app:3000/api/v1/webhooks/waha"');
    expect(stack).toContain("deskcommcrm-waha-block");
    expect(stack).not.toContain("ports:");
  });
});
