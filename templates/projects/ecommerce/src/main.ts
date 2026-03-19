/**
 * E-commerce Template - {{appName}}
 * A cross-platform shopping app built with Craft
 */

import { state, derived, effect, mount, h, batch } from '@craft-native/stx'
import { Card, Badge, Button, Input } from '@craft-native/stx/components'
import { usePlatform, useHaptics } from '@craft-native/stx/composables'
import { db, window as craftWindow } from '@craft-native/craft'

// Types
interface Product {
  id: string
  name: string
  description: string
  price: number
  image: string
  category: string
  inStock: boolean
}

interface CartItem {
  product: Product
  quantity: number
}

// Reactive State
const products = state<Product[]>([])
const cart = state<CartItem[]>([])
const currentView = state<'home' | 'cart' | 'product'>('home')
const selectedProductId = state<string | null>(null)

// Composables
const platform = usePlatform()
const haptics = useHaptics()

// Derived
const cartCount = derived(() => cart().length)
const cartTotal = derived(() =>
  cart().reduce((sum, item) => sum + (item.product.price * item.quantity), 0),
)
const selectedProduct = derived(() =>
  products().find(p => p.id === selectedProductId()),
)

// Database
async function initDatabase(): Promise<void> {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS cart (
      productId TEXT PRIMARY KEY,
      quantity INTEGER DEFAULT 1
    )
  `)
}

async function loadProducts(): Promise<void> {
  // Sample products - replace with API call
  products.set([
    { id: '1', name: 'Product 1', description: 'Description', price: 29.99, image: '', category: 'Category', inStock: true },
    { id: '2', name: 'Product 2', description: 'Description', price: 49.99, image: '', category: 'Category', inStock: true },
    { id: '3', name: 'Product 3', description: 'Description', price: 19.99, image: '', category: 'Category', inStock: false },
  ])
}

// Cart functions
function addToCart(productId: string): void {
  const product = products().find(p => p.id === productId)
  if (!product) return

  const currentCart = cart()
  const existingItem = currentCart.find(item => item.product.id === productId)

  if (existingItem) {
    cart.set(currentCart.map(item =>
      item.product.id === productId
        ? { ...item, quantity: item.quantity + 1 }
        : item,
    ))
  } else {
    cart.set([...currentCart, { product, quantity: 1 }])
  }

  if (platform.os === 'ios' || platform.os === 'android') {
    haptics.notification('success')
  }
}

function removeFromCart(productId: string): void {
  cart.set(cart().filter(item => item.product.id !== productId))
}

// Navigation
function navigate(view: 'home' | 'cart' | 'product', productId?: string): void {
  batch(() => {
    currentView.set(view)
    selectedProductId.set(productId || null)
  })
}

// Views
function renderProductCard(product: Product) {
  return Card({},
    h('div', { class: 'product-card', onClick: () => navigate('product', product.id) },
      h('div', { class: 'product-image' }),
      h('h3', {}, product.name),
      h('p', { class: 'price' }, `$${product.price.toFixed(2)}`),
      Button({
        onClick: (e: Event) => { e.stopPropagation(); addToCart(product.id) },
        disabled: !product.inStock,
      }, product.inStock ? 'Add to Cart' : 'Out of Stock'),
    ),
  )
}

function HomeView() {
  return h('div', { class: 'products-grid' },
    ...products().map(product => renderProductCard(product)),
  )
}

function CartView() {
  const items = cart()

  if (items.length === 0) {
    return h('div', { class: 'empty-state' },
      h('p', {}, 'Your cart is empty'),
    )
  }

  return h('div', { class: 'cart' },
    ...items.map(item =>
      Card({},
        h('div', { class: 'cart-item' },
          h('span', {}, `${item.product.name} x${item.quantity}`),
          h('span', {}, `$${(item.product.price * item.quantity).toFixed(2)}`),
          Button({ onClick: () => removeFromCart(item.product.id) }, 'Remove'),
        ),
      ),
    ),
    h('div', { class: 'cart-total' },
      h('strong', {}, `Total: $${cartTotal().toFixed(2)}`),
    ),
    Button({ class: 'checkout-btn' }, 'Checkout'),
  )
}

function ProductDetailView() {
  const product = selectedProduct()
  if (!product) return h('p', {}, 'Product not found')

  return h('div', { class: 'product-detail' },
    Button({ onClick: () => navigate('home') }, '\u2190 Back'),
    h('div', { class: 'product-image large' }),
    h('h2', {}, product.name),
    h('p', {}, product.description),
    h('p', { class: 'price' }, `$${product.price.toFixed(2)}`),
    Button({
      onClick: () => addToCart(product.id),
      disabled: !product.inStock,
    }, product.inStock ? 'Add to Cart' : 'Out of Stock'),
  )
}

function App() {
  const view = currentView()

  let content: ReturnType<typeof h>
  switch (view) {
    case 'home':
      content = HomeView()
      break
    case 'cart':
      content = CartView()
      break
    case 'product':
      content = ProductDetailView()
      break
  }

  return h('div', { class: 'app' },
    h('header', { class: 'header' },
      h('h1', {}, '{{appName}}'),
      Button({ class: 'cart-btn', onClick: () => navigate('cart') },
        '\uD83D\uDED2 ',
        Badge({}, String(cartCount())),
      ),
    ),
    h('main', {}, content),
    h('nav', { class: 'bottom-nav' },
      Button({
        onClick: () => navigate('home'),
        class: view === 'home' ? 'active' : '',
      }, 'Home'),
      Button({
        onClick: () => navigate('cart'),
        class: view === 'cart' ? 'active' : '',
      }, 'Cart'),
    ),
  )
}

// Initialize and mount
async function init(): Promise<void> {
  await initDatabase()
  await loadProducts()

  craftWindow.setTitle('{{appName}}')
  craftWindow.setSize(400, 800)

  mount(App, '#app')
}

init()
