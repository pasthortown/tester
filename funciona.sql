/****** Object:  StoredProcedure [config].[USP_cnf_restauranteformapagos]    Script Date: 19/1/2021 15:14:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
======================================================================================================================================
DESARROLLADO POR: Christian Pinto
DESCRIPCION: Trae las tiendas para agregar en las formas de pago
TABLAS INVOLUCRADAS: Restaurante, Restaurante_Atributos, Config_Restaurante_Atributos, Formapago
FECHA CREACION: 10/06/2015
======================================================================================================================================
FECHA ULTIMA MODIFICACION: 29/01/2016
USUARIO QUE MODIFICO: Christian Pinto
DECRIPCION ULTIMO CAMBIO: Cambio de Tabla de colecciones antiguas a actuales
TABLAS INVOLUCRADAS: ColeccionRestaurante, RestauranteColeccionDeDatos, ColeccionDeDatosRestaurante
======================================================================================================================================
FECHA MODIFICACION   : 23/03/2018
USUARIO QUE MODIFICO : Daniel Llerena
DECRIPCION CAMBIO    : Se agrega los estados en varibles
======================================================================================================================================
*/

ALTER PROCEDURE [config].[USP_cnf_restauranteformapagos]
(
	@idcadena					INT
	, @idformapago				VARCHAR(40)
	, @aplica					INT
	, @idrestaurantes			VARCHAR(8000)
	, @user						VARCHAR(40)
	, @descripcionformapago		VARCHAR(200)
)	 
AS
BEGIN

	SET NOCOUNT ON;

	--En Tabla "RestauranteColeccionDeDatos" el campo "variableB" lo utilizamos para el Estado Activo=1 Inactivo=0
	--En Tabla "RestauranteColeccionDeDatos" el campo "intDescripcion" lo utilizamos para el CodigoUsuario
	--En Tabla "RestauranteColeccionDeDatos" el campo "variableV" lo utilizamos para la forma de pago a la cual aplica

	DECLARE @accion								INT
			, @restauranteActivo				VARCHAR(40)
			, @ID_ColeccionRestaurante			VARCHAR(40)
			, @ID_ColeccionDeDatosRestaurante	VARCHAR(40)
			, @mdl_id							INT
			, @rst_id							INT
			, @estado							FLOAT
			, @Descripcion						VARCHAR(200)
			, @DescripFormaPago					VARCHAR(200)
			, @rst_cod_tienda					VARCHAR(100)
			, @formapago_activo					VARCHAR(40)

	SET @restauranteActivo	= (config.fn_estado('Restaurante', 'Activo'));
	SET @formapago_activo	= (config.fn_estado('FormaPago', 'Activo'));
		
	SET @ID_ColeccionRestaurante = 
	(
		SELECT ID_ColeccionRestaurante 
		FROM	ColeccionRestaurante WITH(NOLOCK)
		WHERE	Descripcion = 'APLICA FORMAS PAGO RESTAURANTE'
				AND cdn_id = @idcadena
				AND isActive = 1
	);

    SET @mdl_id = (SELECT mdl_id FROM Modulo WITH(NOLOCK) WHERE mdl_descripcion = 'FormaPago');
    SET @Descripcion = 'FORMAS PAGO';
	
	IF (@idformapago != '0')
	BEGIN	
		SET @DescripFormaPago = 
		(
			SELECT	fmp_descripcion 
			FROM	Formapago WITH(NOLOCK) 
			WHERE	cdn_id = @idcadena 
					AND IDFormapago = @idformapago 
					AND IDStatus = @formapago_activo
		);
	END

	/* Tabla tempotal para restaurantes */
	DECLARE @tmp_restaurante TABLE 
	(
		id					INT IDENTITY (1, 1)
		, id_restaurante	INT
		, codigo_tienda		VARCHAR(4)
		, estado			INT
	)

	DECLARE @id_restaurante		INT
			, @codigo_tienda	VARCHAR(4)
			, @estado_rest		INT
			, @totalregistos	INT
			, @icontador		INT

	IF (@aplica = 0)
	BEGIN
		DECLARE @tmp_aplica_restaurante TABLE 
		(
			id_restaurante		INT
			, codigo_tienda		VARCHAR(204)
			, rsat_bit			INT
			, agregado			INT
		)

		INSERT INTO @tmp_aplica_restaurante
		SELECT	r.rst_id
				, (r.rst_cod_tienda + '_' + r.rst_descripcion) AS rst_descripcion
				, rcd.variableB AS rsat_bit
				, 1 AS agregado
				
		FROM	ColeccionRestaurante AS cr WITH(NOLOCK)
				INNER JOIN ColeccionDeDatosRestaurante AS cdr WITH(NOLOCK) ON cdr.ID_ColeccionRestaurante = cr.ID_ColeccionRestaurante
				INNER JOIN RestauranteColeccionDeDatos AS rcd WITH(NOLOCK) ON rcd.ID_ColeccionDeDatosRestaurante = cdr.ID_ColeccionDeDatosRestaurante AND rcd.ID_ColeccionRestaurante = cr.ID_ColeccionRestaurante
				INNER JOIN Restaurante AS r WITH(NOLOCK) ON r.rst_id = rcd.rst_id AND r.IDStatus = @restauranteActivo
				INNER JOIN Formapago AS fp WITH(NOLOCK) ON CAST(fp.IDFormapago AS VARCHAR(40)) = rcd.variableV AND fp.IDStatus = @formapago_activo
		WHERE	cr.cdn_id = @idcadena 
				AND cr.Descripcion = 'APLICA FORMAS PAGO RESTAURANTE'
				AND cr.isActive = 1
				AND cdr.isActive = 1
				AND rcd.isActive = 1
				AND rcd.variableB IN (0, 1)
				AND fp.IDFormapago = @idformapago 

		SELECT	rst_id
				, (rst_cod_tienda+'_'+rst_descripcion) AS rst_descripcion
				, 0 AS rsat_bit
				, 0 AS agregado 
		FROM	Restaurante WITH(NOLOCK) 
		WHERE	cdn_id = @idcadena 
				AND rst_id NOT IN (SELECT id_restaurante FROM @tmp_aplica_restaurante)
				AND IDStatus = @restauranteActivo

		UNION ALL

		SELECT	id_restaurante AS rst_id
				, codigo_tienda AS rst_descripcion
				, rsat_bit
				, agregado   
		FROM	@tmp_aplica_restaurante
		ORDER BY	rst_descripcion ASC	

		SET @accion = 0;
    END
	ELSE IF (@aplica = 1)
	BEGIN		
		
		--select @ID_ColeccionRestaurante
        DECLARE CURSORITO CURSOR
        FOR
        SELECT  rst_id
              , rst_cod_tienda
              , estado = 0
        FROM    Restaurante
        WHERE   cdn_id = @idcadena
                AND rst_id NOT IN (SELECT   CONVERT(INT, Items) AS Items
                                   FROM     Split(@idrestaurantes, ','))
                AND rst_id <> 0
                AND IDStatus = @restauranteActivo
        UNION
        SELECT  CONVERT(INT, Items) AS rst_id
				, (SELECT rst_cod_tienda FROM Restaurante WHERE rst_id = CONVERT(INT, Items) AND IDStatus = @restauranteActivo) AS rst_cod_tienda
				, estado = 1
        FROM    Split(@idrestaurantes, ',')
        WHERE   Items <> 0;

        OPEN CURSORITO; 

        FETCH NEXT FROM CURSORITO 

		INTO @rst_id, @rst_cod_tienda, @estado;
        WHILE @@fetch_status = 0
            BEGIN
                IF OBJECT_ID('tempdb..##i_seg_pantalla1') IS NOT NULL 
                BEGIN
                    DROP TABLE #i_seg_pantalla1;
                END;
                ELSE
                BEGIN
                    CREATE TABLE #i_seg_pantalla1 (ID_ColeccionDeDatosRestaurante VARCHAR(40)); --creamos tabla temporal para almacenar ultimo id
                END;

				--SELECT * FROM RestauranteColeccionDeDatos WHERE rst_id=@rst_id AND variableV=@idformapago and ID_ColeccionRestaurante=@ID_ColeccionRestaurante
                IF NOT EXISTS (SELECT 1 FROM RestauranteColeccionDeDatos WHERE rst_id = @rst_id AND variableV = @idformapago AND ID_ColeccionRestaurante = @ID_ColeccionRestaurante)
                BEGIN											
                    INSERT  INTO ColeccionDeDatosRestaurante
                    (
                        Descripcion
						, tipodedato
						, isActive
						, lastUpdate
						, lastUser
						, ID_ColeccionRestaurante
                    )
                    OUTPUT  INSERTED.ID_ColeccionDeDatosRestaurante
                            INTO #i_seg_pantalla1 --insertamos el ultimo id insertado en la tabla temporal
                    VALUES  
					(
                        @Descripcion + '_' + @DescripFormaPago + '_' + @rst_cod_tienda
						, 'i'
						, 1
						, GETDATE()
						, @user
						, @ID_ColeccionRestaurante
                    );
								
                    SET @ID_ColeccionDeDatosRestaurante = (SELECT ID_ColeccionDeDatosRestaurante FROM #i_seg_pantalla1 ); --almacenamos id de la tabla temporal	

                    INSERT  INTO RestauranteColeccionDeDatos
                    (
                        rst_id
						, ID_ColeccionDeDatosRestaurante
						, variableV
						, intDescripcion
						, variableB
						, fechaIni
						, isActive
						, lastUpdate
						, lastUser
						, ID_ColeccionRestaurante
						, mdl_id
                    )
                    VALUES  
					(
                        @rst_id
						, @ID_ColeccionDeDatosRestaurante
						, @idformapago
						, @user
						, @estado
						, GETDATE()
						, 1
						, GETDATE()
						, @user
						, @ID_ColeccionRestaurante
						, @mdl_id
                    );

					-- AUDITORIA										
                    IF (@estado = 1)
                    BEGIN
                        DECLARE @descripcionupdate VARCHAR(200);

                        SET @descripcionupdate = 'Codigo Forma Pago: '
                            + CAST(@idformapago AS VARCHAR) + ', '
                            + 'Descripcion: ' + @descripcionformapago
                            + ',' + 'Aplica Codigo Restaurante: '
                            + CAST(@rst_id AS VARCHAR) + ', '
                            + 'Estado: Activo';

                        EXECUTE config.IAE_Audit_registro 'i', @user, @rst_id, 'FORMAS DE PAGO', @descripcionupdate, 'MODIFICAR';
                    END;
                    ELSE
                    BEGIN
                        DECLARE @descripcionupdatei VARCHAR(200);

                        SET @descripcionupdatei = 'Codigo Forma Pago: '
                            + CAST(@idformapago AS VARCHAR) + ', '
                            + 'Descripcion: ' + @descripcionformapago
                            + ',' + 'Aplica Codigo Restaurante: '
                            + CAST(@rst_id AS VARCHAR) + ', '
                            + 'Estado: Inactivo';

                        EXECUTE config.IAE_Audit_registro 'i', @user, @rst_id, 'FORMAS DE PAGO', @descripcionupdatei, 'MODIFICAR';
                    END;						
                END;
                ELSE
                BEGIN
                    IF EXISTS (SELECT 1 FROM RestauranteColeccionDeDatos WHERE rst_id = @rst_id AND variableB <> @estado AND variableV = CAST(@idformapago AS VARCHAR))
                    BEGIN
                        IF (@estado = 1)
                        BEGIN
                            DECLARE @descripcionupdateactivo VARCHAR(200);

                            SET @descripcionupdateactivo = 'Codigo Forma Pago: '
                                + CAST(@idformapago AS VARCHAR)
                                + ', ' + 'Descripcion: '
                                + @descripcionformapago + ','
                                + 'Aplica Codigo Restaurante: '
                                + CAST(@rst_id AS VARCHAR) + ', '
                                + 'Estado: Activo';

                            EXECUTE config.IAE_Audit_registro 'i', @user, @rst_id, 'FORMAS DE PAGO', @descripcionupdateactivo, 'MODIFICAR';
                        END;
                        ELSE
                        BEGIN
                            DECLARE @descripcionupdateinactivo VARCHAR(200);

                            SET @descripcionupdateinactivo = 'Codigo Forma Pago: '
                                + CAST(@idformapago AS VARCHAR)
                                + ', ' + 'Descripcion: '
                                + @descripcionformapago + ','
                                + 'Aplica Codigo Restaurante: '
                                + CAST(@rst_id AS VARCHAR) + ', '
                                + 'Estado: Inactivo';

                            EXECUTE config.IAE_Audit_registro 'i', @user, @rst_id, 'FORMAS DE PAGO', @descripcionupdateinactivo, 'MODIFICAR';
                        END;										
                    END; 

                    UPDATE  RestauranteColeccionDeDatos
                    SET     variableB = @estado
                            , fechaIni = GETDATE()
                            , fechaFin = NULL
                    WHERE   variableV = @idformapago
                            AND rst_id = @rst_id;--SOLO TIENDAS SELECCIONADOS
                END;
								 
                DROP TABLE #i_seg_pantalla1;
                FETCH NEXT FROM CURSORITO 
       			INTO @rst_id, @rst_cod_tienda, @estado;
            END; 

        CLOSE CURSORITO; 
        DEALLOCATE CURSORITO;

		SET @accion=2		
		SELECT	@accion AS AccionFormaPago
				, 0 AS rst_id
				, 0 AS rst_descripcion
				, 0 AS agregado
				, 0 AS rsat_bit	
	END
	ELSE IF @aplica = 3
	BEGIN
		SELECT	rst_id	
				, (rst_cod_tienda+'_'+rst_descripcion) AS rst_descripcion
				, 0 AS rsat_bit
				, 0 AS agregado 
		FROM	Restaurante 
		WHERE	cdn_id = @idcadena
				AND IDStatus = @restauranteActivo
		ORDER BY	rst_descripcion ASC
	END 
	ELSE IF @aplica = 4
	BEGIN
		BEGIN TRY 
		BEGIN TRANSACTION
		
			INSERT INTO @tmp_restaurante
			SELECT  CONVERT(INT, Items) AS rst_id
					, (SELECT rst_cod_tienda FROM Restaurante WITH(NOLOCK) WHERE rst_id = CONVERT(INT, Items) AND IDStatus = @restauranteActivo) AS rst_cod_tienda
					, estado = 1
			FROM    Split(@idrestaurantes, ',')
			WHERE   Items <> 0;				 

			SET @icontador = 1; 
			SELECT @totalregistos = COUNT(1) FROM @tmp_restaurante; 

			WHILE @icontador <= @totalregistos 
			BEGIN 
				SELECT	@id_restaurante = id_restaurante
						, @codigo_tienda = codigo_tienda
						, @estado_rest = estado 
				FROM   	@tmp_restaurante 
				WHERE  	id = @icontador 
      
				SET @icontador = @icontador + 1;

				IF OBJECT_ID('tempdb..#i_seg_pantalla') IS NOT NULL
				BEGIN
					DROP TABLE #i_seg_pantalla;
				END ELSE
				BEGIN
					-- creamos tabla temporal para almacenar ultimo id
					CREATE TABLE #i_seg_pantalla (ID_ColeccionDeDatosRestaurante VARCHAR(40));
				END;								

				IF NOT EXISTS 
				(
					SELECT	1 
					FROM	RestauranteColeccionDeDatos WITH(NOLOCK)
					WHERE	rst_id = @id_restaurante 
							AND variableV = @idformapago
							AND ID_ColeccionRestaurante = @ID_ColeccionRestaurante
				)
				BEGIN					
					INSERT  INTO ColeccionDeDatosRestaurante
					(
						Descripcion
						, tipodedato
						, isActive
						, lastUpdate
						, lastUser
						, ID_ColeccionRestaurante
					)

					OUTPUT INSERTED.ID_ColeccionDeDatosRestaurante INTO #i_seg_pantalla
					 
					VALUES  
					(
						@Descripcion + '_' + @DescripFormaPago + '_' + @rst_cod_tienda
						, 'i'
						, 1
						, GETDATE()
						, @user
						, @ID_ColeccionRestaurante
					);
					
					--almacenamos id de la tabla temporal								
					SET @ID_ColeccionDeDatosRestaurante = (SELECT ID_ColeccionDeDatosRestaurante FROM #i_seg_pantalla);
											 											 
					INSERT  INTO RestauranteColeccionDeDatos
					(
						rst_id
						, ID_ColeccionDeDatosRestaurante
						, variableV
						, intDescripcion
						, variableB
						, fechaIni
						, isActive
						, lastUpdate
						, lastUser
						, ID_ColeccionRestaurante
						, mdl_id
					)
					VALUES  
					(
						@id_restaurante
						, @ID_ColeccionDeDatosRestaurante
						, @idformapago
						, @user
						, 1 --@estado
						, GETDATE()
						, 1
						, GETDATE()
						, @user
						, @ID_ColeccionRestaurante
						, @mdl_id
					);

					--AUDITORIA
					SET @descripcionupdate = 'Codigo Forma Pago: '
						+ CAST(@idformapago AS VARCHAR) + ', '
						+ 'Descripcion: ' + @descripcionformapago
						+ ',' + 'Aplica Codigo Restaurante: '
						+ CAST(@id_restaurante AS VARCHAR) + ', '
						+ 'Estado: Activo';

					EXECUTE config.IAE_Audit_registro 'i', @user, @id_restaurante, 'FORMAS DE PAGO', @descripcionupdate,'INSERT';
				END;
				ELSE
				BEGIN	
					IF EXISTS 
					(
						SELECT	1 
						FROM	RestauranteColeccionDeDatos WITH(NOLOCK) 
						WHERE	rst_id = @id_restaurante 
								AND ID_ColeccionDeDatosRestaurante = '3' 
								AND variableB <> @estado 
								AND variableV = CAST(@idformapago AS VARCHAR) 
					)
					BEGIN
						
						IF (@estado = 1)
						BEGIN
							SET @descripcionupdateactivo = 'Codigo Forma Pago: '
								+ CAST(@idformapago AS VARCHAR) + ', '
								+ 'Descripcion: '
								+ @descripcionformapago + ','
								+ 'Aplica Codigo Restaurante: '
								+ CAST(@id_restaurante AS VARCHAR) + ', '
								+ 'Estado: Activo';

							EXECUTE config.IAE_Audit_registro 'i', @user, @id_restaurante, 'FORMAS DE PAGO', @descripcionupdateactivo, 'MODIFICAR';
						END;
						ELSE
						BEGIN
							SET @descripcionupdateinactivo = 'Codigo Forma Pago: '
								+ CAST(@idformapago AS VARCHAR) + ', '
								+ 'Descripcion: '
								+ @descripcionformapago + ','
								+ 'Aplica Codigo Restaurante: '
								+ CAST(@id_restaurante AS VARCHAR) + ', '
								+ 'Estado: Inactivo';

							EXECUTE config.IAE_Audit_registro 'i', @user, @id_restaurante, 'FORMAS DE PAGO', @descripcionupdateinactivo, 'MODIFICAR';
						END;										
					END;
				
					UPDATE  RestauranteColeccionDeDatos
					SET     variableB = @estado
							, fechaIni = GETDATE()
							, fechaFin = NULL
					WHERE   variableV = @idformapago
							AND rst_id = @id_restaurante;--SOLO TIENDAS SELECCIONADOS
				END;
								 
				DROP TABLE #i_seg_pantalla;	  
			END 

		SET @accion = 3;
				
		SELECT	@accion AS AccionFormaPago
				, 0		AS rst_id
				, 0		AS rst_descripcion
				, 0		AS agregado
				, 0		AS rsat_bit	

	COMMIT TRANSACTION 
		END TRY
		BEGIN CATCH
			SELECT ERROR_NUMBER() AS ErrorNumber,
			ERROR_SEVERITY() AS ErrorSeverity,
			ERROR_STATE() AS ErrorState,
			ERROR_PROCEDURE() AS ErrorProcedure,
			ERROR_LINE() AS ErrorLine,
			ERROR_MESSAGE() AS ErrorMessage
		ROLLBACK TRANSACTION;
		END CATCH

	END
END