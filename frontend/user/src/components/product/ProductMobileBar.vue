<template>
  <Transition
    enter-active-class="transition duration-300 ease-out"
    enter-from-class="translate-y-full opacity-0"
    enter-to-class="translate-y-0 opacity-100"
    leave-active-class="transition duration-200 ease-in"
    leave-from-class="translate-y-0 opacity-100"
    leave-to-class="translate-y-full opacity-0">
    <div v-if="visible"
      class="lg:hidden fixed bottom-0 left-0 right-0 z-40 bg-card/95 backdrop-blur-xl border-t shadow-2xl theme-safe-bottom">
      <div class="flex items-center gap-3 px-4 py-3">
        <!-- Price -->
        <div class="flex-1 min-w-0">
          <span v-if="availableAmounts" class="theme-price-sm text-primary truncate block">{{ availableAmounts }}</span>
          <span v-else-if="showMemberPrice" class="theme-price-sm text-amber-600 dark:text-amber-300 truncate block">
            {{ memberPriceDisplay }}
          </span>
          <span v-else-if="showSkuPromotionPrice" class="theme-price-sm text-rose-600 dark:text-rose-300 truncate block">
            {{ skuPromotionPriceDisplay }}
          </span>
          <span v-else-if="showSkuPrice" class="theme-price-sm text-primary truncate block">
            {{ skuPriceDisplay }}
          </span>
          <span v-else-if="showProductPromotionPrice" class="theme-price-sm text-rose-600 dark:text-rose-300 truncate block">
            {{ productPromotionPriceDisplay }}
          </span>
          <span v-else class="theme-price-sm text-primary truncate block">
            {{ productPriceDisplay }}
          </span>
        </div>
        <!-- Actions -->
        <Button v-if="!purchasingEnabled" size="lg" class="rounded-xl font-bold text-slate-200 disabled:opacity-100" :aria-label="t('products.comingSoon')" disabled>
          <ShoppingCart class="h-4 w-4 text-amber-300" />
        </Button>
        <Button v-else-if="!canPurchase" size="lg" class="rounded-xl font-bold" disabled>
          {{ t('products.stockStatus.outOfStock') }}
        </Button>
        <Button v-else-if="requiresLogin" size="lg" class="rounded-xl font-bold" @click="$emit('goLogin')">
          {{ t('productDetail.loginToBuy') }}
        </Button>
        <template v-else>
          <Button variant="secondary" size="lg" class="rounded-xl font-bold" :disabled="!canPurchase" @click="$emit('addToCart')">
            {{ t('productDetail.addToCart') }}
          </Button>
          <Button size="lg" class="rounded-xl font-bold" :disabled="!canPurchase" @click="$emit('buyNow')">
            {{ t('productDetail.buyNow') }}
          </Button>
        </template>
      </div>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { ShoppingCart } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'

const { t } = useI18n()

defineProps<{
  visible: boolean
  requiresLogin: boolean
  canPurchase: boolean
  purchasingEnabled: boolean
  availableAmounts: string
  showMemberPrice: boolean
  memberPriceDisplay: string
  showSkuPromotionPrice: boolean
  skuPromotionPriceDisplay: string
  showSkuPrice: boolean
  skuPriceDisplay: string
  showProductPromotionPrice: boolean
  productPromotionPriceDisplay: string
  productPriceDisplay: string
}>()

defineEmits<{
  addToCart: []
  buyNow: []
  goLogin: []
}>()
</script>
