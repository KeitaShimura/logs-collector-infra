CLUSTER := logs-cluster                    # k3d クラスター名
REQUIRED_CTX := k3d-$(CLUSTER)              # 必要な kubectl コンテキスト名

.PHONY: create delete apply teardown ctx diff guard-context print-vars

create:                                     # k3d クラスター作成
	k3d cluster create $(CLUSTER) --config k3d/cluster.yaml
	kubectl config use-context $(REQUIRED_CTX)

delete: guard-context                       # k3d クラスター削除
	@echo "🗑  Deleting cluster $(CLUSTER)"
	k3d cluster delete $(CLUSTER)

apply: guard-context                        # マニフェスト適用
	@echo "🚀 Applying to $(REQUIRED_CTX)"
	kubectl --context $(REQUIRED_CTX) diff -k k8s/overlays/local || true
	# 毎回マイグレーション実行したいので既存Jobを削除（なければ無視）
	kubectl --context $(REQUIRED_CTX) -n logs-system delete job db-migrate --ignore-not-found
	# マニフェスト適用（db/migrations含む）
	kubectl --context $(REQUIRED_CTX) apply -k k8s/overlays/local
	# 任意：DB起動とJob完了を待つ（失敗時ログ確認用）
	kubectl --context $(REQUIRED_CTX) -n logs-system rollout status statefulset/db
	kubectl --context $(REQUIRED_CTX) -n logs-system wait --for=condition=complete job/db-migrate --timeout=180s || (echo "❌ migration failed"; kubectl -n logs-system logs job/db-migrate; exit 1)

teardown: guard-context                     # マニフェスト削除
	@echo "🧹 Deleting manifests from $(REQUIRED_CTX)"
	kubectl --context $(REQUIRED_CTX) delete -k k8s/overlays/local || true

ctx:                                        # コンテキスト切替 & 確認
	kubectl config use-context $(REQUIRED_CTX)
	kubectl config get-contexts
	kubectl --context $(REQUIRED_CTX) get nodes -o wide
	kubectl --context $(REQUIRED_CTX) get ns

diff: guard-context                         # マニフェスト差分表示
	kubectl --context $(REQUIRED_CTX) diff -k k8s/overlays/local || true

# ===== 安全確認：間違った context での実行防止 =====
guard-context:
	@CTX=$$(kubectl config current-context | tr -d '[:space:]'); \
	REQ=$$(echo "$(REQUIRED_CTX)" | tr -d '[:space:]'); \
	if [ "$$CTX" != "$$REQ" ]; then \
		echo "❌ STOP: current-context=$$CTX. Please switch to $$REQ before running this command."; \
		exit 1; \
	else \
		echo "✅ context=$$CTX OK"; \
	fi

print-vars:                                 # デバッグ用：変数値表示
	@printf 'REQUIRED_CTX=[%s]\n' "$(REQUIRED_CTX)"
	@printf 'CURRENT(kubectl)=[%s]\n' "$$(kubectl config current-context)"
