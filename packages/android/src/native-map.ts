/** Build-time native map selection. Both providers are native Android views. */
export type AndroidMapProvider = 'google' | 'maplibre'

export function androidMapHost(provider: AndroidMapProvider = 'google'): { template: string, imports: string, dependency: string } {
  if (provider === 'google') return {
    template: 'CraftNativeMapGoogle.kt.template',
    imports: `import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.MapView
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions
import com.google.android.gms.maps.model.Polyline
import com.google.android.gms.maps.model.PolylineOptions`,
    dependency: 'com.google.android.gms:play-services-maps:18.2.0',
  }
  if (provider === 'maplibre') return {
    template: 'CraftNativeMapLibre.kt.template',
    imports: `import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.location.LocationComponentActivationOptions
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.OnMapReadyCallback
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.SymbolLayer
import org.maplibre.android.style.layers.PropertyFactory.*
import org.maplibre.android.style.sources.GeoJsonSource`,
    dependency: 'org.maplibre.gl:android-sdk:13.7.1',
  }
  throw new Error(`Unknown Android native map provider: ${provider}. Expected google or maplibre.`)
}
