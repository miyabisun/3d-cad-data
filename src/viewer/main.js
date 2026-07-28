import * as THREE from 'three';
import { OrbitControls } from '/vendor/examples/jsm/controls/OrbitControls.js';
import { STLLoader } from '/vendor/examples/jsm/loaders/STLLoader.js';

const viewport = document.querySelector('#viewport');
const modelSelect = document.querySelector('#model-select');
const dimensions = document.querySelector('#dimensions');
const status = document.querySelector('#status');
const storageKey = 'stl-viewer:model';

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x0d0f0c);
scene.fog = new THREE.Fog(0x0d0f0c, 500, 1800);

const camera = new THREE.PerspectiveCamera(42, 1, 0.1, 10_000);
camera.up.set(0, 0, 1);
camera.position.set(140, -180, 120);

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
viewport.append(renderer.domElement);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;

const grid = new THREE.GridHelper(1000, 100, 0x626b52, 0x292d25);
grid.rotation.x = Math.PI / 2;
scene.add(grid);

scene.add(new THREE.HemisphereLight(0xf4f0d8, 0x252a20, 2.2));
const keyLight = new THREE.DirectionalLight(0xffffff, 3.4);
keyLight.position.set(-150, -100, 240);
scene.add(keyLight);

const loader = new STLLoader();
const material = new THREE.MeshStandardMaterial({
  color: 0xdbe955,
  metalness: 0.08,
  roughness: 0.58,
});
let mesh = null;
let loadVersion = 0;

function setStatus(message, isError = false) {
  status.textContent = message;
  status.dataset.error = String(isError);
}

function fitCamera(geometry) {
  geometry.computeBoundingSphere();
  const sphere = geometry.boundingSphere;
  const radius = Math.max(sphere.radius, 1);
  const direction = new THREE.Vector3(1, -1.3, 0.85).normalize();
  const distance = radius / Math.sin(THREE.MathUtils.degToRad(camera.fov / 2));

  controls.target.copy(sphere.center);
  camera.position.copy(sphere.center).addScaledVector(direction, distance * 1.15);
  camera.near = Math.max(distance / 1000, 0.01);
  camera.far = distance * 20;
  camera.updateProjectionMatrix();
  controls.update();
}

function loadModel(file, preserveCamera = false) {
  if (!file) {
    if (mesh) {
      scene.remove(mesh);
      mesh.geometry.dispose();
      mesh = null;
    }
    dimensions.textContent = '—';
    setStatus('No STL files found');
    return;
  }

  const currentVersion = ++loadVersion;
  setStatus('Loading…');
  loader.load(
    `/models/${file.split('/').map(encodeURIComponent).join('/')}?t=${Date.now()}`,
    (geometry) => {
      if (currentVersion !== loadVersion) {
        geometry.dispose();
        return;
      }

      geometry.computeVertexNormals();
      geometry.computeBoundingBox();
      const size = geometry.boundingBox.getSize(new THREE.Vector3());
      dimensions.textContent = `${size.x.toFixed(1)} × ${size.y.toFixed(1)} × ${size.z.toFixed(1)} mm`;

      const nextMesh = new THREE.Mesh(geometry, material);
      if (mesh) {
        scene.remove(mesh);
        mesh.geometry.dispose();
      }
      mesh = nextMesh;
      scene.add(mesh);
      if (!preserveCamera) fitCamera(geometry);
      setStatus(preserveCamera ? 'Updated' : 'Ready');
    },
    undefined,
    (error) => {
      console.error(error);
      setStatus('Could not load model', true);
    },
  );
}

async function refreshModels() {
  try {
    const response = await fetch('/api/models');
    if (!response.ok) {
      throw new Error(`Model list request failed: ${response.status}`);
    }
    const models = await response.json();
    const previous = modelSelect.value || localStorage.getItem(storageKey);
    const selected = models.includes(previous) ? previous : models[0] || '';

    modelSelect.replaceChildren(
      ...models.map((file) => new Option(file, file, false, file === selected)),
    );
    modelSelect.disabled = models.length === 0;

    if (selected !== previous || !mesh) loadModel(selected);
  } catch (error) {
    console.error(error);
    setStatus('Could not scan models', true);
  }
}

modelSelect.addEventListener('change', () => {
  localStorage.setItem(storageKey, modelSelect.value);
  loadModel(modelSelect.value);
});

const events = new EventSource('/events');
events.onmessage = ({ data }) => {
  const event = JSON.parse(data);
  if (event.type === 'change' && event.file === modelSelect.value) {
    loadModel(event.file, true);
  } else if (event.type === 'add' || event.type === 'unlink') {
    refreshModels();
  }
};
events.onerror = () => setStatus('Reconnecting…', true);
events.onopen = () => {
  if (mesh) setStatus('Ready');
};

function resize() {
  const { clientWidth, clientHeight } = viewport;
  camera.aspect = clientWidth / clientHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(clientWidth, clientHeight, false);
}

window.addEventListener('resize', resize);
resize();
refreshModels();

renderer.setAnimationLoop(() => {
  controls.update();
  renderer.render(scene, camera);
});
