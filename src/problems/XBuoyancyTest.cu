#include "XBuoyancyTest.h"
#include <cmath>
#include <iostream>

#include "GlobalData.h"
#include "cudasimframework.cuh"
#include "Cube.h"
#include "Sphere.h"
#include "Point.h"
#include "Vector.h"


XBuoyancyTest::XBuoyancyTest(GlobalData *_gdata) : XProblem(_gdata)
{
	// Size and origin of the simulation domain
	double lx = 1.0;
	double ly = 1.0;
	double lz = 1.0;
	double H = 0.7;

	//m_size = make_double3(lx, ly, lz);
	//m_origin = make_double3(0.0, 0.0, 0.0);

	SETUP_FRAMEWORK(
		kernel<WENDLAND>,
		viscosity<ARTVISC>,
		//viscosity<SPSVISC>,
		//viscosity<KINEMATICVISC>,
		boundary<DYN_BOUNDARY>
	);

	// SPH parameters
	set_deltap(0.02); //0.008
	m_simparams.slength = 1.3*m_deltap;
	m_simparams.kernelradius = 2.0;
	m_simparams.kerneltype = WENDLAND;
	m_simparams.dt = 0.0003f;
	m_simparams.xsph = false;
	m_simparams.dtadapt = true;
	m_simparams.dtadaptfactor = 0.3;
	m_simparams.buildneibsfreq = 10;
	m_simparams.ferrari = 0;
	m_simparams.tend = 20.0f; //0.00036f

	// Free surface detection
	m_simparams.surfaceparticle = false;
	m_simparams.savenormals = false;

	// Vorticity
	m_simparams.vorticity = false;

	// We have no moving boundary
	m_simparams.mbcallback = false;

	// Physical parameters
	H = 0.6f;
	m_physparams.gravity = make_float3(0.0, 0.0, -9.81f);
	double g = length(m_physparams.gravity);
	m_physparams.set_density(0, 1000.0, 7.0f, 20.f);

	//set p1coeff,p2coeff, epsxsph here if different from 12.,6., 0.5
	m_physparams.dcoeff = 5.0f*g*H;
	m_physparams.r0 = m_deltap;

	m_physparams.kinematicvisc[0] = 1.0e-6f;
	m_physparams.artvisccoeff = 0.3f;
	m_physparams.epsartvisc = 0.01*m_simparams.slength*m_simparams.slength;

	add_writer(VTKWRITER, 0.01);

	setPositioning(PP_CORNER);

	const int layers = 4;

	GeometryID cube = addBox(GT_FIXED_BOUNDARY, FT_BORDER, Point(0,0,0), lx, ly, lz);
	disableCollisions(cube);

	// makeUniverseBox also sets origin and size
	makeUniverseBox(make_double3(0.0, 0.0, 0.0), make_double3(lx, ly, lz) );

	const double offs = m_deltap * layers;
	//addExtraWorldMargin(2*offs);

	GeometryID fluid = addBox(GT_FLUID, FT_SOLID, Point(offs, offs, offs),
		lx - 2.0 * offs, ly - 2.0 * offs, H);

	// TODO
	/*
	switch (object_type) {
		case 0: {
			olx, oly, olz = 10.0*m_deltap;
			cube  = Cube(Point(lx/2.0 - olx/2.0, ly/2.0 - oly/2.0, H/2.0 - olz/2.0), olx, oly, olz);
		case 1: {
			double r = 6.0*m_deltap;
			sphere = Sphere(Point(lx/2.0, ly/2.0, H/2.0 - r/4.0), r);
		case 2: // TORUS
	*/
	double R = lx * 0.2;
	double r = 4.0 * m_deltap;
	GeometryID torus = addTorus(GT_FLOATING_BODY, FT_BORDER, Point(lx/2.0, ly/2.0, H/2.0), R, r);
	setMassByDensity(torus, m_physparams.rho0[0]*0.5);

	// Name of problem used for directory creation
	m_name = "XBuoyancyTest";
}

void XBuoyancyTest::ODE_near_callback(void *data, dGeomID o1, dGeomID o2)
{
	const int N = 10;
	dContact contact[N];

	int n = dCollide(o1, o2, N, &contact[0].geom, sizeof(dContact));
	for (int i = 0; i < n; i++) {
		contact[i].surface.mode = dContactBounce;
		contact[i].surface.mu   = dInfinity;
		contact[i].surface.bounce     = 0.0; // (0.0~1.0) restitution parameter
		contact[i].surface.bounce_vel = 0.0; // minimum incoming velocity for bounce
		dJointID c = dJointCreateContact(m_ODEWorld, m_ODEJointGroup, &contact[i]);
		dJointAttach (c, dGeomGetBody(contact[i].geom.g1), dGeomGetBody(contact[i].geom.g2));
	}
}